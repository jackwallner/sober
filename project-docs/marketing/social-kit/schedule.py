#!/usr/bin/env python3
"""Write the TikTok experiment schedule to iCloud "Sober Social Kit/Schedule.csv".

    python3 schedule.py [start YYYY-MM-DD]     # default 2026-11-03

Weeks 1 to 3 follow the research matrix (research-2026-11.md section 6): 12 post types
rotated across the 6:30, 11:30 and 17:30 PT slots so type and slot aren't confounded.
Dated seasonal posts take the 11:30 slot on their date; the Dry January series takes
6:30 every day in January. After week 3, drop the bottom three types (see README).
"""

from __future__ import annotations

import csv
import datetime as dt
import sys

import build_kit as K
import build_v2 as B
import posts as P
import posts2 as P2

SLOTS = ["06:30", "11:30", "17:30"]
MATRIX = [
    [1, 2, 4], [3, 6, 7], [10, 5, 1], [2, 9, 11], [12, 3, 6], [7, 1, 5], [4, 10, 8],
    [6, 2, 3], [1, 11, 9], [5, 12, 7], [10, 4, 2], [3, 8, 1], [9, 6, 11], [7, 5, 12],
    [2, 3, 4], [11, 10, 6], [1, 9, 8], [12, 7, 3], [6, 2, 5], [4, 11, 10], [8, 1, 12],
]


def pools() -> dict[int, list[dict]]:
    old = {p["id"]: p for p in P.POSTS}
    new = {p["id"]: p for p in P2.POSTS2}
    vids = {v["id"]: v for v in P2.VIDEOS}

    def take(src, ids):
        return [src[i] for i in ids]

    return {
        1: take(new, ["N1", "N2", "N3", "N4", "N5", "N6"]),
        2: take(old, ["C1", "C2", "C3", "C4", "C5", "C6"]),
        3: take(old, ["D1", "D2", "D3", "D4", "D5", "D6"]),
        4: take(vids, ["T1", "T2", "T3", "T4", "T5", "T8"]),
        5: take(vids, ["R1", "R2", "R3"]) + take(old, ["B1", "B5", "B3"]),
        6: take(vids, [f"V{n}" for n in range(1, 11)]),
        7: take(new, ["K1", "K2", "K3", "K4", "K5", "K6"]),
        8: take(new, ["Q1", "Q2", "Q3", "Q4", "Q5", "Q6"]),
        9: take(new, ["P1", "P2", "P3", "P4", "P5", "P6"]),
        10: take(new, ["S1", "S2", "S3", "S4", "S5", "S6"]),
        11: take(old, ["G1", "G2", "G3", "G4", "G5", "G6"]),
        12: take(new, ["M1", "M2", "M3", "M4", "M5", "M6"]),
    }


def path_for(post: dict) -> str:
    if post["id"] in {p["id"] for p in P.POSTS}:
        i = next(k for k, p in enumerate(K.schedule()) if p["id"] == post["id"])
        name = f"Day {i // 3 + 1:02d}/{K.SLOT_NAMES[i % 3]} - {post['id']} {P.FORMATS[post['fmt']]}"
        return name
    if "kind" in post:
        return f"Wave 2/{post['type']:02d} {P2.TYPES[post['type']]}/{post['id']}.mp4"
    return str(B.folder_for(post).relative_to(K.ICLOUD))


def label(post: dict) -> str:
    return post.get("hook") or " / ".join(post["beats"])


def main() -> None:
    start = dt.date.fromisoformat(sys.argv[1] if len(sys.argv) > 1 else "2026-11-03")
    pool = pools()
    dated = {p["date"]: p for p in P2.POSTS2 if "date" in p}
    rows = []
    for n, types in enumerate(MATRIX):
        day = start + dt.timedelta(days=n)
        for slot, t in zip(SLOTS, types):
            if slot == "11:30" and day.isoformat() in dated:
                post = dated.pop(day.isoformat())
            else:
                post = pool[t].pop(0)
            rows.append((day, slot, post))
    for d, post in sorted(dated.items()):
        rows.append((dt.date.fromisoformat(d), "11:30", post))
    for post in B.dryjan_posts():
        rows.append((dt.date.fromisoformat(post["date"]), "06:30", post))
    rows.sort(key=lambda r: (r[0], r[1]))
    with open(K.ICLOUD / "Schedule.csv", "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["date", "time_pt", "id", "type", "format", "hook", "path", "scheduled", "views_72h",
                    "saves", "shares", "comments", "app_comments", "profile_views"])
        for day, slot, post in rows:
            t = post.get("type") or {"A": 1, "B": 5, "C": 2, "D": 3, "E": 13, "F": 12, "G": 11}[post["fmt"]]
            fmt = "video" if "kind" in post else "photo"
            w.writerow([day.isoformat(), slot, post["id"], P2.TYPES[t], fmt, label(post), path_for(post),
                        "", "", "", "", "", "", ""])
    print(f"{len(rows)} rows, {rows[0][0]} to {rows[-1][0]}")


if __name__ == "__main__":
    main()
