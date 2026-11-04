#!/usr/bin/env python3
"""Render posts_v3 into iCloud "Sober Social Kit/Page v3/<id>/" and write its contact sheets.

    python3 page/build_v3.py [H01 H07 ...]

Footage lives in Page v3/stock (see CREDITS.txt). A post whose clip isn't there is skipped and reported.
"""

from __future__ import annotations

import json
import pathlib
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw
from scipy.io import wavfile

HERE = pathlib.Path(__file__).resolve().parent
sys.path[:0] = [str(HERE), str(HERE.parent)]

import build_kit as K  # noqa: E402
import posts_v3 as P  # noqa: E402
from samples_v2 import SAFETY, font, type_layer, wrap  # noqa: E402

OUT = K.ICLOUD / "Page v3"
STOCK = OUT / "stock"
GRADE = "eq=brightness=-0.06:saturation=0.85"
BOTTOM_LIMIT = 1480  # TikTok's caption block covers the frame below this


def duration(path: pathlib.Path) -> float:
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)],
                         capture_output=True, text=True, check=True)
    return float(out.stdout)


def frame(post: dict, src: pathlib.Path, total: float) -> str:
    start = post.get("start", 0)
    room = duration(src) - start
    flip = ",hflip" if post.get("flip") else ""
    if post["clip"] == P.HALLWAY:  # landscape, and it needs the heavy slow-down to read as a held shot
        return f"crop=608:1080:346:0,scale=1080:1920,setpts=3.3*PTS,minterpolate=fps=30:mi_mode=blend,eq=brightness=-0.20:saturation=0.55:contrast=1.08{flip}"
    stretch = f"setpts={(total + 0.5) / room:.3f}*PTS,minterpolate=fps=30:mi_mode=blend," if room < total + 0.5 else ""
    return f"scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,{stretch}fps=30,{GRADE}{flip}"


def layers(post: dict, tmp: pathlib.Path) -> None:
    d = ImageDraw.Draw(Image.new("L", (1, 1)))
    size = 104
    first = wrap(d, post["beats"][0], font(size), 860)
    while len(first) > 5 and size > 80:
        size -= 8
        first = wrap(d, post["beats"][0], font(size), 860)
    second = wrap(d, post["beats"][1], font(84), 860)
    end = 430 + int(size * 1.16) * len(first) + 54 + int(84 * 1.16) * len(second)
    if end > BOTTOM_LIMIT:
        raise SystemExit(f"{post['id']} type runs to y={end}")
    y = type_layer(first, 430, size, tmp / f"{post['id']}a.png")
    type_layer(second, y + 54, 84, tmp / f"{post['id']}b.png")


def render(post: dict, src: pathlib.Path, tmp: pathlib.Path) -> None:
    words = len(post["beats"][0].split())
    second_at = round(max(2.4, min(4.2, 0.27 * words)), 1)
    total = round(second_at + max(3.4, 0.38 * len(post["beats"][1].split())), 1)
    layers(post, tmp)
    buf = K.R.score(total, total - 1.0)[: int(total * K.R.SR)]
    wav = tmp / f"{post['id']}.wav"
    wavfile.write(wav, K.R.SR, (0.5 * buf / (np.abs(buf).max() + 1e-9) * 32767).astype(np.int16))
    folder = OUT / post["id"]
    folder.mkdir(parents=True, exist_ok=True)
    start = post.get("start", 1.5 if post["clip"] == P.HALLWAY else 0)
    graph = (f"[0:v]{frame(post, src, total)}[v];[v][1:v]overlay=0:0[a];"
             f"[a][2:v]overlay=0:0:enable='gte(t,{second_at})'[out]")
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-ss", str(start), "-i", str(src),
                    "-loop", "1", "-i", str(tmp / f"{post['id']}a.png"), "-loop", "1", "-i", str(tmp / f"{post['id']}b.png"),
                    "-i", str(wav), "-filter_complex", graph, "-map", "[out]", "-map", "3:a", "-t", str(total),
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-b:v", "6000k", "-maxrate", "7000k", "-bufsize", "12000k",
                    "-c:a", "aac", "-b:a", "128k", "-movflags", "+faststart", str(folder / f"{post['id']}.mp4")], check=True)
    caption = f"{post['caption']} {SAFETY if post['heavy'] else ''} {post['tags']}".replace("  ", " ")
    (folder / "caption.txt").write_text(caption + "\n")
    (folder / "post.json").write_text(json.dumps({**post, "second_at": second_at, "total": total, "caption_full": caption}, indent=1))
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-ss", str(total - 0.5), "-i", str(folder / f"{post['id']}.mp4"),
                    "-frames:v", "1", "-q:v", "3", str(folder / "preview.jpg")], check=True)


def main() -> None:
    only = set(sys.argv[1:])
    missing = []
    with tempfile.TemporaryDirectory() as tmp:
        for post in P.POSTS:
            if only and post["id"] not in only:
                continue
            found = sorted(STOCK.glob(f"{post['clip']}*"))
            if not found:
                missing.append(post["id"])
                continue
            render(post, found[0], pathlib.Path(tmp))
            print(post["id"], flush=True)
    if missing:
        print("no footage yet:", " ".join(missing))


if __name__ == "__main__":
    main()
