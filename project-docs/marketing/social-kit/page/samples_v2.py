#!/usr/bin/env python3
"""Render the hooks-v2 samples into iCloud "Sober Social Kit/Page v2 samples/".

    python3 page/samples_v2.py

Footage: free Pexels clips kept in that folder's stock/ (see stock/CREDITS.txt). The hook is on
screen from the very first frame; the second beat lands after it has been read.
"""

from __future__ import annotations

import pathlib
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.io import wavfile

HERE = pathlib.Path(__file__).resolve().parent
sys.path[:0] = [str(HERE), str(HERE.parent)]

import build_kit as K  # noqa: E402  (the kit's original score)

OUT = K.ICLOUD / "Page v2 samples"
STOCK = OUT / "stock"
W, H = 1080, 1920
FONT = "/System/Library/Fonts/SFNS.ttf"
SAFETY = ("If you drink heavily every day, talk to a doctor before you stop. Withdrawal can be dangerous. "
          "US: SAMHSA's free helpline is 1-800-662-4357, 24/7.")

# video filter: frame it vertically, slow it if short, and grade it down so the type carries.
SAMPLES = [
    {"id": "S1", "src": "8862328-uhd_2160_4096_25fps.mp4", "total": 7.0, "second": 2.9,
     "vf": "scale=1080:-2,crop=1080:1920,fps=30,eq=brightness=-0.03:saturation=0.85",
     "beats": ["Somebody in your house counts your drinks too.", "They just stopped saying it out loud."],
     "caption": f"What would they say if you asked? {SAFETY}",
     "tags": "#sobercurious #quitdrinking #greyareadrinking"},
    {"id": "S2", "src": "5203510-hd_1920_1080_30fps.mp4", "total": 7.0, "second": 2.7,
     "start": 1.5,  # the clip opens on a door passing the lens
     "vf": "crop=608:1080:346:0,scale=1080:1920,setpts=3.3*PTS,minterpolate=fps=30:mi_mode=blend,eq=brightness=-0.20:saturation=0.55:contrast=1.08",
     "beats": ["You told your doctor half the real number.", "What's the real number?"],
     "caption": f"Your doctor has heard every number there is. Say the real one out loud, even just to yourself. {SAFETY}",
     "tags": "#sobercurious #quitdrinking #alcoholfree"},
    {"id": "S3", "src": "14904126_2160_3840_30fps.mp4", "total": 7.0, "second": 2.7,
     "vf": "scale=1080:1920,fps=30,eq=brightness=-0.06",
     "beats": ["You're waiting for it to get bad enough.", "You're allowed to stop before that."],
     "caption": f"There's no line you have to cross first. Today can be Day 1. {SAFETY}",
     "tags": "#sobertok #quitdrinking #greyareadrinking"},
]


def font(size: int) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(FONT, size)
    f.set_variation_by_name("Heavy")
    return f


def wrap(d, text: str, f, width: int) -> list[str]:
    lines, cur = [], ""
    for word in text.split(" "):
        trial = f"{cur} {word}".strip()
        if d.textlength(trial, font=f) <= width or not cur:
            cur = trial
        else:
            lines.append(cur)
            cur = word
    return lines + [cur]


def type_layer(lines: list[str], y: int, size: int, path: pathlib.Path) -> int:
    """Big white type with a heavy outline, the look people already read on TikTok."""
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    f = font(size)
    for ln in lines:
        d.text((W // 2 - 24, y), ln, font=f, fill=(255, 255, 255), anchor="ma",
               stroke_width=max(6, size // 12), stroke_fill=(0, 0, 0))
        y += int(size * 1.16)
    im.save(path)
    return y


def render(s: dict, tmp: pathlib.Path) -> pathlib.Path:
    d = ImageDraw.Draw(Image.new("L", (1, 1)))
    first = wrap(d, s["beats"][0], font(104), 860)
    second = wrap(d, s["beats"][1], font(84), 860)
    y = type_layer(first, 430, 104, tmp / f"{s['id']}a.png")
    type_layer(second, y + 54, 84, tmp / f"{s['id']}b.png")
    buf = K.R.score(s["total"], s["total"] - 1.0)[: int(s["total"] * K.R.SR)]
    wav = tmp / f"{s['id']}.wav"
    wavfile.write(wav, K.R.SR, (0.5 * buf / (np.abs(buf).max() + 1e-9) * 32767).astype(np.int16))
    folder = OUT / s["id"]
    folder.mkdir(parents=True, exist_ok=True)
    out = folder / f"{s['id']}.mp4"
    graph = (f"[0:v]{s['vf']}[v];[v][1:v]overlay=0:0[a];"
             f"[a][2:v]overlay=0:0:enable='gte(t,{s['second']})'[out]")
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-ss", str(s.get("start", 0)), "-i", str(STOCK / s["src"]),
                    "-loop", "1", "-i", str(tmp / f"{s['id']}a.png"), "-loop", "1", "-i", str(tmp / f"{s['id']}b.png"),
                    "-i", str(wav), "-filter_complex", graph, "-map", "[out]", "-map", "3:a", "-t", str(s["total"]),
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-b:v", "6000k", "-maxrate", "7000k", "-bufsize", "12000k",
                    "-c:a", "aac", "-b:a", "128k", "-movflags", "+faststart", str(out)], check=True)
    (folder / "caption.txt").write_text(f"{s['caption']} {s['tags']}\n")
    return out


def main() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        for s in SAMPLES:
            print(render(s, pathlib.Path(tmp)).name, flush=True)


if __name__ == "__main__":
    main()
