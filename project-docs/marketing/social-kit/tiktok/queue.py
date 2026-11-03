#!/usr/bin/env python3
"""Stage the TikTok queue: one folder per slot with its files, title and caption.

    python3 tiktok/queue.py                 # writes iCloud "Sober Social Kit/Queue" and queue.json
    rsync -a --delete ".../Sober Social Kit/Queue/" elsa-mac:sober-social-kit/Queue/
    node tiktok/schedule.mjs Queue/queue.json [--only 2026-11-03]

Modes (what each slot tests):
  warm  value only: no app slide, no app in the caption (account warm-up)
  soft  no app slide, the app named once at the end of the caption
  full  app slide (or the video's app end card) plus the caption CTA
"Your brand" disclosure is on for every post (the handle and the tree are the brand).
Captions end with "search ..." because scheduled posts can't count on replying to "app" comments.
"""

from __future__ import annotations

import datetime as dt
import json
import os
import pathlib
import shutil
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import build_kit as K  # noqa: E402
import build_v2 as B  # noqa: E402
import build_v3 as B3  # noqa: E402
import posts as P  # noqa: E402
import posts2 as P2  # noqa: E402
import posts3 as P3  # noqa: E402
import video3 as V3  # noqa: E402

QUEUE = K.ICLOUD / "Queue"
# Paths the uploading Chrome reads. The Air's own Chrome (9227) by default; SOBER_REMOTE=1 for jmbp2.
REMOTE = "/Users/jmbp2/sober-social-kit/Queue" if os.environ.get("SOBER_REMOTE") else str(K.ICLOUD / "Queue")
# PT. Mahj Tips posts at 06:30, 11:30 and 17:30; these stay 45+ minutes clear of it. 16:15 is 7:15 PM ET,
# 18:30 is 9:30 PM ET, the evening craving peak (research-2026-11b.md). Weekend mornings go early (8:30 AM ET).
SLOTS = ["07:15", "16:15", "18:30"]
WEEKEND_MORNING = "05:30"

# 2026-11-03 (Tue) to 2026-11-12 (Thu), TikTok Studio's 10-day window. Video first (24 of 30),
# carousels are the save-worthy test track. Days 1-2 are warm-up: no app slide, no app in the caption.
LINEUP = [
    ("2026-11-03", [("V10", "warm"), ("A1", "warm"), ("R2", "warm")]),
    ("2026-11-04", [("E2", "warm"), ("S1", "warm"), ("V5", "warm")]),
    ("2026-11-05", [("T1", "full"), ("E1", "soft"), ("Nt1", "full")]),
    ("2026-11-06", [("E3", "soft"), ("V1", "soft"), ("F1", "soft")]),
    ("2026-11-07", [("V2", "soft"), ("A2", "soft"), ("R1", "full")]),
    ("2026-11-08", [("V8", "soft"), ("I1", "full"), ("E5", "soft")]),
    ("2026-11-09", [("T3", "full"), ("E4", "soft"), ("V9", "soft")]),
    ("2026-11-10", [("B1", "full"), ("A3", "soft"), ("V7", "soft")]),
    ("2026-11-11", [("T2", "full"), ("E6", "soft"), ("L2", "soft")]),
    ("2026-11-12", [("V6", "full"), ("D2", "full"), ("A4", "soft")]),
]

FULL_CTA = f'I built the app in this post: {P.APP}. Search "{P.SEARCH}" on the App Store, it\'s free to start.'
SEARCH_CTA = f'Search "{P.SEARCH}" on the App Store, it\'s free to start.'
SOFT_CTA = (f'PS: I built an app where a bonsai grows with every sober day. Search "{P.SEARCH}" '
            "on the App Store, it's free to start.")
VIDEO_Q = {4: "What day are you on?", 5: "Did it help? Comment a number from 1 to 10.", 6: "Who else?"}
BASE_TAGS = ["#sobertok", "#sobercurious"]
TOPIC_TAGS = {"timelapse": ["#bonsai", "#alcoholfree"], "breathe": ["#breathwork", "#cravings"],
              "S1": ["#quitdrinking", "#alcoholfree"], "Nt1": ["#cravings", "#quitdrinking"],
              "I1": ["#sobermilestone", "#alcoholfree"], "B1": ["#cravings", "#quitdrinking"],
              "L2": ["#mocktails", "#nonalcoholic"], "D2": ["#moneytips", "#greyareadrinking"]}

W1 = {p["id"]: p for p in P.POSTS}
W2 = {p["id"]: p for p in P2.POSTS2}
VIDS = {v["id"]: v for v in P2.VIDEOS}
W3 = {p["id"]: p for p in P3.POSTS3}
LOOPS = {v["id"]: v for v in V3.LOOPS}


def resolve(pid: str, mode: str) -> dict:
    """Files, title, body text, hashtags and kind for one post id in one mode."""
    app = mode == "full"
    if pid in LOOPS:
        v = LOOPS[pid]
        return {"kind": "video", "files": [V3.OUT / f"{pid}.mp4"], "title": " ".join(v["beats"]),
                "body": v["caption"], "safety": False, "type": "Loop " + v["kind"], "look": v["look"],
                "tags": v["tags"]}
    if pid in VIDS:
        v = VIDS[pid]
        f = K.ICLOUD / "Wave 2" / f"{v['type']:02d} {P2.TYPES[v['type']]}" / f"{pid}.mp4"
        title = v.get("hook") or " ".join(v["beats"])
        return {"kind": "video", "files": [f], "title": title, "body": f"{v['caption']} {VIDEO_Q[v['type']]}",
                "safety": False, "type": P2.TYPES[v["type"]], "look": v["kind"], "tags": TOPIC_TAGS[v["kind"]]}
    if pid in W3:
        p = W3[pid]
        folder = B3.folder_for(p, app or not p["app"])
        files = sorted(folder.glob("*.jpg"), key=lambda x: int(x.stem))
        return {"kind": "photo", "files": files, "title": p["hook"], "body": f"{p['caption']} {p['close']}",
                "safety": False, "type": "Wave 3 " + pid.rstrip("0123456789"), "look": p["look"],
                "tags": TOPIC_TAGS[pid]}
    if pid in W2:
        p = W2[pid]
        files = sorted(B.folder_for(p).glob("*.jpg"), key=lambda x: int(x.stem))
        if not app:
            files.pop(-2 if not p.get("short") else -1)
        body = f"{p['caption']} {P2.QUESTIONS.get(p['type'], '')}".strip()
        return {"kind": "photo", "files": files, "title": p["hook"], "body": body,
                "safety": p["type"] in (1, 14), "type": P2.TYPES[p["type"]], "look": "morning",
                "tags": TOPIC_TAGS[pid]}
    p = W1[pid]
    folder = next(K.ICLOUD.glob(f"Day */* - {pid} *"))
    files = sorted(folder.glob("*.jpg"), key=lambda x: int(x.stem))
    if not app:
        files.pop(3)
    return {"kind": "photo", "files": files, "title": p["hook"], "body": f"{p['caption']} {P.QUESTIONS[p['fmt']]}",
            "safety": p["fmt"] in "AF", "type": P.FORMATS[p["fmt"]], "look": "morning", "tags": TOPIC_TAGS[pid]}


def caption(r: dict, mode: str) -> str:
    parts = [r["body"]]
    if mode != "warm":
        parts.append(SEARCH_CTA if r["body"].startswith("I built") else FULL_CTA if mode == "full" else SOFT_CTA)
    if r["safety"]:
        parts.append(P.SAFETY)
    parts.append(" ".join(BASE_TAGS + r["tags"]))
    return "\n\n".join(parts)


def main() -> None:
    shutil.rmtree(QUEUE, ignore_errors=True)
    QUEUE.mkdir(parents=True)
    out = []
    for day, posts in LINEUP:
        weekend = dt.date.fromisoformat(day).weekday() >= 5
        slots = [WEEKEND_MORNING if weekend else SLOTS[0], *SLOTS[1:]]
        for slot, (pid, mode) in zip(slots, posts):
            r = resolve(pid, mode)
            name = f"{day} {slot.replace(':', '')} {pid} {mode}"
            folder = QUEUE / name
            folder.mkdir()
            remote = []
            for i, f in enumerate(r["files"], 1):
                dst = folder / f"{i}{f.suffix}"
                shutil.copy2(f, dst)
                remote.append(f"{REMOTE}/{name}/{dst.name}")
            text = caption(r, mode)
            (folder / "caption.txt").write_text(f"{r['title']}\n\n{text}\n")
            out.append({"date": day, "time": slot, "id": pid, "mode": mode, "kind": r["kind"], "type": r["type"],
                        "look": r["look"], "title": r["title"][:90], "caption": text, "files": remote,
                        "tags": " ".join(BASE_TAGS + r["tags"]), "disclose": True})
            print(f"{day} {slot} {pid:4} {mode:4} {r['kind']:5} {len(r['files'])} {r['title']}")
    (QUEUE / "queue.json").write_text(json.dumps(out, indent=1))
    print(len(out), "slots")


if __name__ == "__main__":
    main()
