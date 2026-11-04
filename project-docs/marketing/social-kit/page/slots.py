#!/usr/bin/env python3
"""Assign POSTS to slots and write iCloud "Sober Social Kit/Page v1/Schedule.csv" and queue.json.

    python3 page/slots.py [start YYYY-MM-DD] [first slot 0-2]

Dated posts are written for the slot they land in with the defaults, so check the
hooks if the start moves: C02 needs Nov 5 or close to it, C05 and L02 a Friday.
"""

from __future__ import annotations

import csv
import datetime as dt
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import posts as P  # noqa: E402

OUT = pathlib.Path.home() / "Library/Mobile Documents/com~apple~CloudDocs/Sober Social Kit/Page v1"
SOUND = "When It Starts to Rain (Haley Olin)"


def slots(day: dt.date) -> list[str]:
    return ["05:30" if day.weekday() >= 5 else "07:15", "16:15", "18:30"]


def main() -> None:
    day = dt.date.fromisoformat(sys.argv[1]) if len(sys.argv) > 1 else dt.date(2026, 11, 4)
    slot = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    rows = []
    for post in P.POSTS:
        rows.append({"date": day.isoformat(), "time": slots(day)[slot], "id": post["id"], "kind": post["kind"],
                     "hook": post.get("hook") or post["beats"][0], "app": post.get("app") or "",
                     "disclose": bool(post.get("app")), "sound": SOUND if post["kind"] == "carousel" else "original",
                     "caption": f"{post['caption']} {' '.join(post['tags'])}"})
        slot += 1
        if slot == 3:
            slot, day = 0, day + dt.timedelta(days=1)
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "queue.json").write_text(json.dumps(rows, indent=1))
    with (OUT / "Schedule.csv").open("w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    for r in rows:
        print(r["date"], r["time"], r["id"], r["app"], r["hook"][:60].replace(" ", " "))


if __name__ == "__main__":
    main()
