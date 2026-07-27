#!/usr/bin/env python3
"""Download and summarize Sober's App Store conversion reports.

Apple suppresses low-volume analytics rows for privacy. Totals from discovery
and sessions therefore undercount real activity; commerce/download reports are
used for the primary funnel where available.
"""
from __future__ import annotations

import argparse
import csv
import gzip
import io
import urllib.request
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import date
from pathlib import Path

import asc_lib

BUNDLE_ID = "com.jackwallner.sober"
REPORT_NAMES = {
    "discovery": "App Store Discovery and Engagement Detailed",
    "downloads": "App Downloads Standard",
    "sessions": "App Sessions Standard",
    "purchases": "App Store Purchases Standard",
    "subscriptions": "App Store Subscription Event Report Standard",
}


@dataclass(frozen=True)
class Report:
    id: str
    name: str


def download_text(url: str) -> str:
    with urllib.request.urlopen(url, timeout=120) as response:
        raw = response.read()
    try:
        raw = gzip.decompress(raw)
    except gzip.BadGzipFile:
        pass
    return raw.decode("utf-8-sig")


def report_map(client: asc_lib.ASCClient, app_id: str) -> dict[str, Report]:
    requests = asc_lib.list_all(client, f"/apps/{app_id}/analyticsReportRequests?limit=200")
    ongoing = next(
        (row for row in requests if row["attributes"].get("accessType") == "ONGOING"),
        None,
    )
    if ongoing is None:
        raise SystemExit("error: no ongoing analytics report request")
    reports = asc_lib.list_all(client, f"/analyticsReportRequests/{ongoing['id']}/reports?limit=200")
    by_name = {row["attributes"]["name"]: Report(row["id"], row["attributes"]["name"]) for row in reports}
    missing = [name for name in REPORT_NAMES.values() if name not in by_name]
    if missing:
        raise SystemExit(f"error: missing ASC reports: {', '.join(missing)}")
    return {key: by_name[name] for key, name in REPORT_NAMES.items()}


def rows_for_report(client: asc_lib.ASCClient, report: Report) -> list[dict[str, str]]:
    instances = asc_lib.list_all(client, f"/analyticsReports/{report.id}/instances?limit=200")
    rows: list[dict[str, str]] = []
    seen: set[tuple[tuple[str, str], ...]] = set()
    for instance in instances:
        if instance["attributes"].get("granularity") != "DAILY":
            continue
        segments = asc_lib.list_all(
            client,
            f"/analyticsReportInstances/{instance['id']}/segments?limit=200",
        )
        for segment in segments:
            text = download_text(segment["attributes"]["url"])
            for row in csv.DictReader(io.StringIO(text), delimiter="\t"):
                key = tuple(row.items())
                if key in seen:
                    continue
                seen.add(key)
                rows.append(row)
    return rows


def in_range(value: str, start: str | None, end: str | None) -> bool:
    return (start is None or value >= start) and (end is None or value <= end)


def summarize(rows: dict[str, list[dict[str, str]]], start: str | None, end: str | None) -> str:
    downloads = [
        row for row in rows["downloads"]
        if row.get("Download Type") == "First-time download" and in_range(row["Date"], start, end)
    ]
    subscriptions = [
        row for row in rows["subscriptions"]
        if in_range(row["Event Date"], start, end)
    ]
    purchases = [row for row in rows["purchases"] if in_range(row["Date"], start, end)]
    discovery = [row for row in rows["discovery"] if in_range(row["Date"], start, end)]
    sessions = [row for row in rows["sessions"] if in_range(row["Date"], start, end)]

    first_downloads = sum(int(row["Counts"]) for row in downloads)
    by_version = Counter()
    by_source = Counter()
    by_page = Counter()
    by_territory = Counter()
    for row in downloads:
        count = int(row["Counts"])
        by_version[row["App Version"]] += count
        by_source[row["Source Type"]] += count
        by_page[row["Page Type"] or "No page"] += count
        by_territory[row["Territory"]] += count

    subscription_events = Counter()
    for row in subscriptions:
        subscription_events[(row["Event Group"], row["Event Name"])] += int(row["Counts"])
    trial_starts = subscription_events[("Offer start", "Free trial start activation")]
    trial_conversions = subscription_events[("Paid subscription from offer", "Full price from free trial")]
    direct_paid = subscription_events[("Paid subscription start", "Full price subscription start activation")]

    paid_purchases = 0
    proceeds = 0.0
    for row in purchases:
        if float(row.get("Proceeds in USD") or 0) > 0:
            paid_purchases += int(row["Purchases"])
            proceeds += float(row["Proceeds in USD"])

    impressions = sum(int(row["Counts"]) for row in discovery if row["Event"] == "Impression")
    page_views = sum(int(row["Counts"]) for row in discovery if row["Event"] == "Page view")
    session_count = sum(int(row["Sessions"]) for row in sessions)
    session_seconds = sum(int(row["Total Session Duration"]) for row in sessions)

    first_date = min((row["Date"] for row in downloads), default=start or "n/a")
    last_date = max((row["Date"] for row in downloads), default=end or "n/a")
    trial_rate = trial_starts / first_downloads * 100 if first_downloads else 0
    trial_paid_rate = trial_conversions / trial_starts * 100 if trial_starts else 0

    lines = [
        "# Sober conversion report",
        "",
        f"Generated: {date.today().isoformat()}",
        f"Download cohort: {first_date} through {last_date}",
        "",
        "> Apple privacy thresholds suppress low-volume discovery and session rows. "
        "Treat those counts as directional minimums, not complete totals.",
        "",
        "## Funnel",
        "",
        f"- First-time downloads: **{first_downloads}**",
        f"- Free-trial starts: **{trial_starts}** ({trial_rate:.1f}% of first-time downloads)",
        f"- Trial-to-paid conversions: **{trial_conversions}** ({trial_paid_rate:.1f}% of trial starts)",
        f"- Direct full-price starts: **{direct_paid}**",
        f"- Paid purchase rows: **{paid_purchases}**, proceeds **${proceeds:.2f}**",
        f"- Privacy-thresholded impressions: **{impressions}**",
        f"- Privacy-thresholded product-page views: **{page_views}**",
        f"- Privacy-thresholded sessions: **{session_count}** "
        f"({session_seconds / session_count:.1f}s average where reported)" if session_count else "- Privacy-thresholded sessions: **0**",
        "",
        "## First-time downloads by version",
        "",
    ]
    lines.extend(f"- {key}: {value}" for key, value in by_version.most_common())
    lines.extend(["", "## Acquisition source", ""])
    lines.extend(f"- {key}: {value}" for key, value in by_source.most_common())
    lines.extend(["", "## Download page type", ""])
    lines.extend(f"- {key}: {value}" for key, value in by_page.most_common())
    lines.extend(["", "## Top territories", ""])
    lines.extend(f"- {key}: {value}" for key, value in by_territory.most_common(20))
    return "\n".join(lines) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--start", help="Inclusive YYYY-MM-DD")
    parser.add_argument("--end", help="Inclusive YYYY-MM-DD")
    parser.add_argument("--output", type=Path, help="Write Markdown report")
    args = parser.parse_args()

    client = asc_lib.ASCClient(asc_lib.bearer_token(*asc_lib.load_credentials()))
    app = asc_lib.find_app(client, BUNDLE_ID)
    reports = report_map(client, app["id"])
    rows = {key: rows_for_report(client, report) for key, report in reports.items()}
    report = summarize(rows, args.start, args.end)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(report, encoding="utf-8")
    print(report, end="")


if __name__ == "__main__":
    main()
