#!/usr/bin/env python3
"""Aggregate Sober's on-device conversion funnel from RevenueCat.

1.2.7 mirrors ConversionDiagnostics counters onto each RevenueCat customer as
`funnel_*` subscriber attributes (see SubscriptionService.syncConversionAttributes).
This walks the customer list and tallies them, which is the only way to separate
"never reached the trial offer" from "reached it and declined".

Only customers first seen on or after 2026-08-17 (the 1.2.7 release) carry the
attributes, so --since defaults to that.

Reads the RevenueCat secret key from the per-app credential file
(~/.sober_credentials, ~/.quitzyn_credentials): a bare key on its own line,
comments start with #. Those keys are project-scoped, so the project id is
passed explicitly rather than discovered by listing.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter
from datetime import date, datetime, timezone
from pathlib import Path

BASE = "https://api.revenuecat.com/v2"
APPS = {
    "sober": ("Sober", "proj10cf6202", Path.home() / ".sober_credentials"),
    "quitzyn": ("Quit Zyn", "proj8395c8fc", Path.home() / ".quitzyn_credentials"),
}
FUNNEL_ORDER = [
    "onboardingReached",
    "onboardingCompleted",
    "trialOfferReached",
    "trialCTATapped",
    "purchaseSucceeded",
    "purchaseCancelled",
    "freeVersionChosen",
]


def secret_key(path: Path) -> str:
    """First non-comment, non-empty line of a per-app credential file."""
    if not path.exists():
        raise SystemExit(f"error: no credential file at {path}")
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            # Accept a bare key, `NAME=value`, or `export NAME="value"`.
            match = re.match(r'^(?:export\s+)?(?:[A-Za-z_][A-Za-z0-9_]*=)?["\']?([^"\'\s]+)', line)
            if match:
                return match.group(1)
    raise SystemExit(f"error: no key found in {path}")


def get(path: str, key: str, params: dict[str, str] | None = None) -> dict:
    # `path` may be a bare path or, when following next_page, a full URL.
    url = path if path.startswith("http") else f"{BASE}{path}"
    if params:
        url += ("&" if "?" in url else "?") + urllib.parse.urlencode(params)
    request = urllib.request.Request(url, headers={"Authorization": f"Bearer {key}"})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                return json.loads(response.read())
        except urllib.error.HTTPError as error:
            if error.code == 429 and attempt < 4:
                time.sleep(2 ** attempt)
                continue
            raise SystemExit(f"error: {error.code} on {url}\n{error.read().decode()[:400]}")
    raise SystemExit(f"error: gave up on {url}")


def paginate(path: str, key: str, params: dict[str, str] | None = None):
    params = dict(params or {})
    params.setdefault("limit", "100")
    while True:
        page = get(path, key, params)
        for item in page.get("items", []):
            yield item
        nxt = page.get("next_page")
        if not nxt:
            return
        # next_page already carries its own query string; don't re-add params.
        path, params = nxt, None


def find_project(key: str, name_fragment: str) -> dict:
    for project in paginate("/projects", key):
        if name_fragment.lower() in project.get("name", "").lower():
            return project
    raise SystemExit(f"error: no project matching {name_fragment!r}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("app", nargs="?", default="sober", choices=sorted(APPS))
    parser.add_argument("--since", default="2026-08-17", help="Only customers first seen on/after (YYYY-MM-DD)")
    parser.add_argument("--max-customers", type=int, default=5000)
    args = parser.parse_args()

    name, project_id, cred_path = APPS[args.app]
    key = secret_key(cred_path)
    cutoff = datetime.strptime(args.since, "%Y-%m-%d").replace(tzinfo=timezone.utc).timestamp() * 1000

    totals: Counter[str] = Counter()
    in_window = 0
    scanned = 0
    instrumented = 0
    for customer in paginate(f"/projects/{project_id}/customers", key):
        scanned += 1
        if scanned > args.max_customers:
            break
        if (customer.get("first_seen_at") or 0) < cutoff:
            continue
        in_window += 1
        attrs = get(f"/projects/{project_id}/customers/{customer['id']}/attributes", key)
        values = {a["name"]: a.get("value") for a in attrs.get("items", [])}
        if not any(k.startswith("funnel_") for k in values):
            continue
        instrumented += 1
        for step in FUNNEL_ORDER:
            raw = values.get(f"funnel_{step}")
            if raw and str(raw).isdigit() and int(raw) > 0:
                totals[step] += 1

    print(f"# {name} funnel, customers first seen >= {args.since}")
    print(f"Generated: {date.today().isoformat()}")
    print(f"Customers scanned: {scanned}, in window: {in_window}, reporting funnel attributes: {instrumented}\n")
    if not instrumented:
        print("No instrumented customers yet. 1.2.7 shipped 2026-08-17; give it time.")
        return
    base = totals.get("onboardingReached") or instrumented
    print(f"{'step':<22} {'users':>6} {'% of onboardingReached':>24}")
    for step in FUNNEL_ORDER:
        count = totals.get(step, 0)
        print(f"{step:<22} {count:>6} {count / base * 100:>23.1f}%")
    offer = totals.get("trialOfferReached", 0)
    tapped = totals.get("trialCTATapped", 0)
    if offer:
        print(f"\nCTA tap rate among users who reached the offer: {tapped / offer * 100:.1f}% ({tapped}/{offer})")


if __name__ == "__main__":
    main()
