#!/usr/bin/env python3
"""Wave 2 videos (posts2.VIDEOS) into iCloud "Sober Social Kit/Wave 2/<type>/<id>.mp4".

    python3 video.py            # all
    python3 video.py --only T1,R1

timelapse: the app's real bonsai growing through a day range, with a ticking day counter.
pov:       two text beats over a tree, 7 s, no end card (reads as native content).
breathe:   a box-breathing guide (in 4, hold 4, out 4, hold 4), then a card for craving mode.
Audio is the animated-shorts engine's original score, so nothing is licensed.
"""

from __future__ import annotations

import argparse
import math
import pathlib
import subprocess
import tempfile

import numpy as np
from PIL import Image, ImageDraw
from scipy.io import wavfile

import build_kit as K
import build_v2 as B
import posts as P
import posts2 as P2

FPS = 30
W, H = K.W, K.H


def ease(x: float) -> float:
    return 0.5 - 0.5 * math.cos(math.pi * max(0.0, min(1.0, x)))


def end_card(text: str, seed: int) -> Image.Image:
    im = K.background(seed)
    d = ImageDraw.Draw(im)
    f = K.font(60, "Semibold")
    y = 300
    for ln in K.balanced(d, text, f, 820):
        d.text((K.CX, y), ln, font=f, fill=K.INK, anchor="mt")
        y += f.size + 18
    B.plant(im, "traditional", 365, K.CX, 1200, 600, label=False)
    K.badge(im, 1260)
    return im


def encode(frames, total: float, card_at: float, out: pathlib.Path) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        wav = pathlib.Path(tmp) / "a.wav"
        buf = K.R.score(total, card_at)[: int(total * K.R.SR)]
        wavfile.write(wav, K.R.SR, (0.55 * buf / (np.abs(buf).max() + 1e-9) * 32767).astype(np.int16))
        kbps = min(int(9.0 * 8 * 1024 / total - 160), 5000)
        p = subprocess.Popen(["ffmpeg", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24",
                              "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-", "-i", str(wav), "-c:v", "libx264",
                              "-pix_fmt", "yuv420p", "-b:v", f"{kbps}k", "-maxrate", f"{kbps}k",
                              "-bufsize", f"{2 * kbps}k", "-c:a", "aac", "-b:a", "128k", "-shortest",
                              "-movflags", "+faststart", str(out)], stdin=subprocess.PIPE)
        for fr in frames:
            p.stdin.write(fr.convert("RGB").tobytes())
        p.stdin.close()
        if p.wait():
            raise SystemExit(f"ffmpeg failed for {out}")


def crossfade(a: Image.Image, b: Image.Image, n: int):
    for k in range(n):
        yield Image.blend(a.convert("RGB"), b.convert("RGB"), (k + 1) / n)


# ---------------------------------------------------------------- kinds

def timelapse(v: dict, seed: int, out: pathlib.Path) -> None:
    d0, d1 = v["days"]
    grow = 6.0 if d1 - d0 <= 40 else 9.0
    hold, card, fade = 1.5, 2.5, 0.4
    total = grow + hold + card
    base = K.background(seed)
    dd = ImageDraw.Draw(base)
    f = K.font(72)
    y = K.text_boxes(base, K.balanced(dd, v["hook"], f, 800), f, 330)
    big, small = K.font(170, "Medium", italic=True), K.font(38, "Semibold")
    ref = B._tree(v["style"], d1)

    def frame(day: int) -> Image.Image:
        im = base.copy()
        d = ImageDraw.Draw(im)
        d.text((K.CX, y + 50), f"{day}", font=big, fill=K.MOSS, anchor="mt")
        d.text((K.CX, y + 250), "DAYS ALCOHOL-FREE", font=small, fill=K.MUTED, anchor="mt")
        t = B._tree(v["style"], day)
        s = min(820 / ref.width, 600 / ref.height)
        t = t.resize((max(1, int(t.width * s)), max(1, int(t.height * s))), Image.LANCZOS)
        im.alpha_composite(t, (K.CX - t.width // 2, 1470 - t.height))
        return im

    def frames():
        last = None
        for k in range(int((grow + hold) * FPS)):
            day = round(d0 + (d1 - d0) * ease(k / (grow * FPS)))
            if last is None or day != last[0]:
                last = (day, frame(day))
            yield last[1]
        endc = end_card("I built a sobriety app where a bonsai grows with every sober day.", seed)
        yield from crossfade(last[1], endc, int(fade * FPS))
        for _ in range(int((card - fade) * FPS)):
            yield endc

    encode(frames(), total, grow + hold, out)


def pov(v: dict, seed: int, out: pathlib.Path) -> None:
    total = 7.0
    base = K.background(seed)
    style, day = v["tree"]
    B.plant(base, style, day, K.CX, 1460, 520, label=False)
    f = K.font(76)
    layers = []
    y = 360
    for beat in v["beats"]:
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        lines = K.balanced(ImageDraw.Draw(layer), beat, f, 820)
        y = K.text_boxes(layer, lines, f, y + len(lines) * (f.size + 24) // 2) + 30
        layers.append(layer)
    starts = [0.3, 2.6]

    def frames():
        cache = {}
        for k in range(int(total * FPS)):
            t = k / FPS
            alphas = tuple(round(min(1.0, max(0.0, (t - s) / 0.25)), 2) for s in starts)
            if alphas not in cache:
                im = base.copy()
                for layer, a in zip(layers, alphas):
                    if a > 0:
                        l2 = layer.copy()
                        l2.putalpha(layer.getchannel("A").point(lambda v, a=a: int(v * a)))
                        im.alpha_composite(l2)
                cache[alphas] = im
            yield cache[alphas]

    encode(frames(), total, total - 1.2, out)


def breathe(v: dict, seed: int, out: pathlib.Path) -> None:
    intro, side, card, fade = 2.5, 4.0, 3.0, 0.4
    rounds = v["rounds"]
    total = intro + rounds * 4 * side + card
    base = K.background(seed)
    d = ImageDraw.Draw(base)
    f = K.font(70)
    K.text_boxes(base, K.balanced(d, v["hook"], f, 800), f, 330)
    S, cx, cy = 600, K.CX, 1000
    x0, y0, x1, y1 = cx - S // 2, cy - S // 2, cx + S // 2, cy + S // 2
    d.rounded_rectangle((x0, y0, x1, y1), 60, outline=K.SAND + (255,), width=10)
    labels = ["Breathe in", "Hold", "Breathe out", "Hold"]
    lf, nf, rf = K.font(64, "Semibold"), K.font(150, "Medium", italic=True), K.font(38, "Semibold")
    # Dot path: up the left side, across the top, down the right, back along the bottom.
    corners = [(x0, y1), (x0, y0), (x1, y0), (x1, y1), (x0, y1)]

    def frame(t: float) -> Image.Image:
        im = base.copy()
        dd = ImageDraw.Draw(im)
        if t < intro:
            dd.text((cx, cy), "Ready?", font=lf, fill=K.INK, anchor="mm")
            return im
        u = t - intro
        rnd, rest = divmod(u, 4 * side)
        phase, within = divmod(rest, side)
        phase = int(phase)
        a, b = corners[phase], corners[phase + 1]
        e = within / side
        px, py = a[0] + (b[0] - a[0]) * e, a[1] + (b[1] - a[1]) * e
        r = 30 + (14 if phase == 0 else 0) * e + (14 if phase == 1 else 0) - (14 * e if phase == 2 else 0)
        dd.ellipse((px - r, py - r, px + r, py + r), fill=K.MOSS + (255,))
        dd.text((cx, cy - 70), labels[phase], font=lf, fill=K.INK, anchor="mm")
        dd.text((cx, cy + 60), str(int(within) + 1), font=nf, fill=K.MOSS, anchor="mm")
        dd.text((cx, y1 + 70), f"Round {int(rnd) + 1} of {rounds}", font=rf, fill=K.MUTED, anchor="mt")
        return im

    def frames():
        last = None
        for k in range(int((intro + rounds * 4 * side) * FPS)):
            last = frame(k / FPS)
            yield last
        endc = end_card("Craving mode in my app breathes with you. It's free.", seed)
        yield from crossfade(last, endc, int(fade * FPS))
        for _ in range(int((card - fade) * FPS)):
            yield endc

    encode(frames(), total, total - card, out)


# ---------------------------------------------------------------- captions

def caption_txt(v: dict, cta: str) -> str:
    q = {4: "What day are you on?", 5: "Did it help? Comment a number from 1 to 10.", 6: "Who else?"}[v["type"]]
    tags = " ".join(P.TAGS + (["#bonsai"] if v["kind"] == "timelapse" else []) + (["#breathwork"] if v["kind"] == "breathe" else []))
    ctas = {"comment": 'Comment "app" and I\'ll reply with the name (full disclosure, I made it).',
            "name": f'The app is {P.APP}. I built it. Search "{P.SEARCH}" on the App Store, it\'s free to start.'}
    title = v.get("hook") or " ".join(v["beats"])
    return (
        f"POST AS: Video.\nHOOK: {title}\n\n"
        f"TIKTOK CAPTION (paste as is):\n{v['caption']} {q}\n\n{ctas[cta]}\n\n{tags}\n\n"
        f"PINNED COMMENT:\n{P.PINNED.replace('The app on slide 4', 'The app')}\n\n"
        f"BEFORE POSTING (TikTok): More options > Disclose post content > Your brand.\n"
        f"SOUND: keep the video's own audio (original score). For POV, a trending Commercial Music Library sound may replace it.\n\n"
        f"TYPE: {v['type']} {P2.TYPES[v['type']]}   CTA: {cta}\n"
    )


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only")
    args = ap.parse_args()
    only = set(args.only.split(",")) if args.only else None
    kinds = {"timelapse": timelapse, "pov": pov, "breathe": breathe}
    for i, v in enumerate(P2.VIDEOS):
        if only and v["id"] not in only:
            continue
        folder = B.OUT / f"{v['type']:02d} {P2.TYPES[v['type']]}"
        folder.mkdir(parents=True, exist_ok=True)
        out = folder / f"{v['id']}.mp4"
        kinds[v["kind"]](v, 300 + i, out)
        (folder / f"{v['id']} caption.txt").write_text(caption_txt(v, "comment" if i % 2 == 0 else "name"))
        print(v["id"], f"{out.stat().st_size / 1e6:.1f} MB", flush=True)


if __name__ == "__main__":
    main()
