#!/usr/bin/env python3
"""Render the sobriety page into iCloud "Sober Social Kit/Page v1/<id>/".

    python3 page/build.py                 # everything
    python3 page/build.py --only C01,L01
    python3 page/build.py --carousels     # skip video

Carousels are plain type. The only app art is one real screenshot on an app slide.
"""

from __future__ import annotations

import argparse
import functools
import math
import pathlib
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = pathlib.Path(__file__).resolve().parent
sys.path[:0] = [str(HERE), str(HERE.parent)]

import posts as P  # noqa: E402

ICLOUD = pathlib.Path.home() / "Library/Mobile Documents/com~apple~CloudDocs/Sober Social Kit"
OUT = ICLOUD / "Page v1"
W, H = 1080, 1920
LEFT, RIGHT, TOP, BOTTOM = 76, 930, 210, 1500
FONT = "/System/Library/Fonts/SFNS.ttf"
FPS = 30

TONES = {
    "ink": {"bg": (13, 13, 15), "fg": (255, 255, 255), "dim": (168, 168, 174), "accent": (255, 214, 10), "card": (30, 30, 33)},
    "paper": {"bg": (255, 255, 255), "fg": (12, 12, 14), "dim": (98, 98, 104), "accent": (10, 92, 255), "card": (242, 242, 245)},
}
BLUE, GREY = (10, 132, 255), (44, 44, 48)
APP_SHOTS = {  # file, crop in capture pixels: the plant stays out of frame
    "craving": ("craving.png", (0, 660, 1206, 1800)),
    "counter": ("timeline.png", (0, 310, 1206, 1745)),
    "money": ("money.png", (20, 545, 1186, 1005)),
}


@functools.cache
def font(size: int, weight: str = "Bold") -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(FONT, size)
    f.set_variation_by_name(weight)
    return f


def wrap(text: str, f, width: int) -> list[str]:
    d = ImageDraw.Draw(Image.new("L", (1, 1)))
    lines: list[str] = []
    cur = ""
    for word in text.split(" "):
        trial = f"{cur} {word}".strip()
        if d.textlength(trial, font=f) <= width or not cur:
            cur = trial
        else:
            lines.append(cur)
            cur = word
    lines.append(cur)
    # Pull a lone last word up by rebalancing the final two lines.
    if len(lines) > 1 and len(lines[-1].split()) == 1 and len(lines[-2].split()) > 2:
        head = lines[-2].split()
        lines[-2], lines[-1] = " ".join(head[:-1]), f"{head[-1]} {lines[-1]}"
    return lines


def draw_block(d, text: str, size: int, y: int, fill, weight="Bold", leading=1.14, x=LEFT, width=RIGHT - LEFT) -> int:
    f = font(size, weight)
    lines = wrap(text, f, width)
    for ln in lines:
        d.text((x, y), ln, font=f, fill=fill)
        y += int(size * leading)
    return y


def fit(text: str, start: int, weight: str, width: int, max_lines: int, floor: int = 44) -> int:
    size = start
    while size > floor and len(wrap(text, font(size, weight), width)) > max_lines:
        size -= 4
    return size


def canvas(tone: str) -> tuple[Image.Image, ImageDraw.ImageDraw, dict]:
    t = TONES[tone]
    im = Image.new("RGB", (W, H), t["bg"])
    return im, ImageDraw.Draw(im), t


def stack(d, items: list[tuple]) -> None:
    """Draw (text, size, weight, fill, leading, gap_before) lines as one block, optically centered."""
    def lines(it):
        return wrap(it[0], font(it[1], it[2]), RIGHT - LEFT)
    total = sum(it[5] + int(len(lines(it)) * it[1] * it[4]) for it in items) - items[0][5]
    y = TOP + int((BOTTOM - TOP - total) * 0.46)
    for n, it in enumerate(items):
        y += it[5] if n else 0
        y = draw_block(d, it[0], it[1], y, it[3], it[2], it[4])


def hook_slide(post: dict) -> Image.Image:
    im, d, t = canvas(post["tone"])
    size = fit(post["hook"], 132, "Heavy", RIGHT - LEFT, 6)
    stack(d, [(post["hook"], size, "Heavy", t["fg"], 1.08, 0), ("Swipe", 48, "Semibold", t["accent"], 1.1, 56)])
    return im


def tip_slide(post: dict, line: str, i: int, numbered: bool, big_label: bool) -> Image.Image:
    im, d, t = canvas(post["tone"])
    title, _, body = line.partition("|")
    if big_label:  # times layout: the label is the small line, the body is the slide
        stack(d, [(title, 76, "Heavy", t["accent"], 1.1, 0),
                  (body, fit(body, 92, "Bold", RIGHT - LEFT, 7), "Bold", t["fg"], 1.14, 40)])
        return im
    items = [(str(i), 84, "Heavy", t["accent"], 1.1, 0)] if numbered else []
    items.append((title, fit(title, 104, "Heavy", RIGHT - LEFT, 5), "Heavy", t["fg"], 1.08, 36))
    if body:
        items.append((body, 60, "Medium", t["dim"], 1.24, 40))
    stack(d, items)
    return im


def number_slide(post: dict, line: str) -> Image.Image:
    im, d, t = canvas(post["tone"])
    figure, _, body = line.partition("|")
    size = fit(figure, 270, "Heavy", RIGHT - LEFT, 1, 90)
    stack(d, [(figure, size, "Heavy", t["accent"], 1.12, 0), (body, 70, "Semibold", t["fg"], 1.18, 44)])
    return im


def chat_slide(post: dict, lines: list[str], upto: int) -> Image.Image:
    """Sent messages stack up across slides, so each swipe adds a bubble."""
    im, d, t = canvas("ink")
    f = font(64, "Medium")
    bubbles = []
    for text in lines[:upto + 1]:
        ls = wrap(text, f, 640)
        bw = max(int(d.textlength(x, font=f)) for x in ls) + 84
        bubbles.append((ls, bw, len(ls) * 80 + 48))
    # When the stack outgrows the frame, keep the newest messages.
    while sum(b[2] + 26 for b in bubbles) > BOTTOM - TOP:
        bubbles.pop(0)
    y = TOP + (BOTTOM - TOP - sum(b[2] + 26 for b in bubbles)) // 2 - 60
    y = max(TOP, y)
    for ls, bw, bh in bubbles:
        x = RIGHT - bw
        d.rounded_rectangle((x, y, x + bw, y + bh), 46, fill=BLUE)
        ty = y + 22
        for ln in ls:
            d.text((x + 42, ty), ln, font=f, fill=(255, 255, 255))
            ty += 80
        y += bh + 26
    return im


def note_slide(post: dict) -> Image.Image:
    """A list on one card: a checklist, or a fill-in sheet when lines end in ':' or '.'."""
    im, d, t = canvas(post["tone"])
    rows = post["slides"]
    fill_in = any(r.endswith(":") for r in rows)
    y = 280
    f = font(60, "Semibold")
    for row in rows:
        if fill_in:
            ruled = row.endswith(":")
            d.text((LEFT, y), row, font=f, fill=t["fg"] if ruled else t["dim"])
            y += 88
            line_x = LEFT + (0 if ruled else 70)
            d.line((line_x, y + (0 if ruled else -24), RIGHT, y + (0 if ruled else -24)), fill=t["dim"], width=3)
            y += 56 if ruled else 44
            continue
        d.rounded_rectangle((LEFT, y + 4, LEFT + 62, y + 66), 16, outline=t["accent"], width=6)
        y = draw_block(d, row, 64, y, t["fg"], "Semibold", 1.2, x=LEFT + 96, width=RIGHT - LEFT - 96) + 64
    return im


def close_slide(post: dict) -> Image.Image:
    im, d, t = canvas(post["tone"])
    text = post["close"]
    stack(d, [(text, fit(text, 124, "Heavy", RIGHT - LEFT, 5), "Heavy", t["fg"], 1.08, 0)])
    return im


def app_slide(post: dict) -> Image.Image:
    """Same voice and type as the tips, then one real screen and the search line."""
    im, d, t = canvas(post["tone"])
    title, body = P.APP_SLIDES[post["app"]]
    y = draw_block(d, title, 84, TOP, t["fg"], "Heavy", 1.08)
    y = draw_block(d, body, 50, y + 22, t["dim"], "Medium", 1.26)
    name, crop = APP_SHOTS[post["app"]]
    shot = Image.open(HERE / "app-shots" / name).convert("RGB").crop(crop)
    room_h, room_w = BOTTOM - y - 130, RIGHT - LEFT
    s = min(room_w / shot.width, room_h / shot.height)
    shot = shot.resize((int(shot.width * s), int(shot.height * s)), Image.LANCZOS)
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, shot.width - 1, shot.height - 1), 44, fill=255)
    sx = LEFT + (room_w - shot.width) // 2
    im.paste(shot, (sx, y + 34), mask)
    d.text((LEFT, y + 34 + shot.height + 36), P.APP_SEARCH, font=font(50, "Bold"), fill=t["accent"])
    return im


def carousel(post: dict) -> list[Image.Image]:
    slides = [hook_slide(post)]
    layout = post["layout"]
    if layout == "chat":
        slides += [chat_slide(post, post["slides"], k) for k in range(len(post["slides"]))]
    elif layout == "note":
        slides.append(note_slide(post))
    elif layout == "number":
        slides += [number_slide(post, s) for s in post["slides"]]
    else:
        numbered = layout == "tips" and post.get("numbered", True)
        slides += [tip_slide(post, s, i + 1, numbered, layout == "times") for i, s in enumerate(post["slides"])]
    if post.get("app"):
        slides.append(app_slide(post))
    slides.append(close_slide(post))
    return slides


def caption_txt(post: dict) -> str:
    return f"{post['caption']} {' '.join(post['tags'])}\n"


# ---------------------------------------------------------------- video scenes

def _grad(top, bottom) -> np.ndarray:
    t = np.linspace(0, 1, H // 2)[:, None, None]
    return np.broadcast_to(np.array(top, float) * (1 - t) + np.array(bottom, float) * t, (H // 2, W // 2, 3)).copy()


def _sprite(r: int, color) -> np.ndarray:
    yy, xx = np.mgrid[-r:r + 1, -r:r + 1]
    dist = np.sqrt(xx ** 2 + yy ** 2) / r
    a = np.clip((1 - dist) * r / 9, 0, 1) * (0.8 + 0.2 * dist)  # soft edge, a faint rim
    return a[..., None] * np.array(color, float)


class Bokeh:
    """Out-of-focus lights seen through a window, drifting slowly."""

    def __init__(self, seed: int, colors, n: int, band: tuple[float, float]):
        rng = np.random.default_rng(seed)
        self.lights = []
        for _ in range(n):
            r = int(rng.uniform(24, 96))
            c = np.array(colors[rng.integers(len(colors))]) * rng.uniform(0.08, 0.3)
            self.lights.append((_sprite(r, c), r, rng.uniform(0, W // 2), rng.uniform(band[0], band[1]) * H // 2,
                                rng.uniform(-5, 5), rng.uniform(-2.5, 2.5), rng.uniform(0, 6.28), rng.uniform(0.2, 0.7)))

    def add(self, img: np.ndarray, t: float) -> None:
        for sp, r, x0, y0, vx, vy, ph, sp_tw in self.lights:
            x, y = int((x0 + vx * t) % (W // 2)), int(y0 + vy * t)
            tw = 0.8 + 0.2 * math.sin(ph + sp_tw * t)
            x1, y1, x2, y2 = max(x - r, 0), max(y - r, 0), min(x + r + 1, W // 2), min(y + r + 1, H // 2)
            if x2 <= x1 or y2 <= y1:
                continue
            img[y1:y2, x1:x2] += sp[y1 - y + r:y2 - y + r, x1 - x + r:x2 - x + r] * tw


@functools.cache
def _clouds(seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    out = np.zeros((H // 2, W // 2, 1))
    for cell, amp in ((90, 1.0), (40, 0.4), (18, 0.15)):
        small = Image.fromarray((rng.random((H // 2 // cell + 2, W // 2 // cell + 2)) * 255).astype("uint8"))
        out[..., 0] += np.asarray(small.resize((W // 2, H // 2), Image.BICUBIC), float) / 255 * amp
    out /= 1.55
    return np.concatenate([out, out[:, ::-1]], axis=1)  # mirrored, so scrolling never shows a seam


def scene_frame(kind: str, seed: int, bokeh: Bokeh | None, t: float, total: float) -> Image.Image:
    p = t / total
    if kind == "night":
        img = _grad((8, 10, 20), (24, 20, 30))
        bokeh.add(img, t)
    elif kind == "dusk":
        img = _grad((22 - 6 * p, 26 - 6 * p, 58 - 8 * p), (196 - 40 * p, 104 - 26 * p, 74 - 14 * p))
        c = np.roll(_clouds(seed), int(t * 7), axis=1)[:, :W // 2]
        img = img * (0.88 + 0.2 * c)
        bokeh.add(img, t)
    else:  # dawn: the sky brightens and the sun clears the horizon
        img = _grad((70 + 34 * p, 102 + 36 * p, 150 + 30 * p), (238 + 10 * p, 176 + 30 * p, 134 + 26 * p))
        yy, xx = np.mgrid[0:H // 2, 0:W // 2]
        sy = (0.92 - 0.1 * p) * H / 2
        glow = np.exp(-(((xx - W / 4) / 300) ** 2 + ((yy - sy) / 240) ** 2))
        img += glow[..., None] * np.array([70, 58, 30])
        c = np.roll(_clouds(seed), int(t * 9), axis=1)[:, :W // 2]
        img = img * (0.9 + 0.16 * c)
    small = Image.fromarray(np.clip(img, 0, 255).astype("uint8"))
    return small.resize((W, H), Image.BICUBIC)


def text_layers(beats: list[str]) -> list[Image.Image]:
    """TikTok's native look: bold black text in white rounded boxes."""
    f = font(68, "Bold")
    layers, y = [], 400
    for beat in beats:
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        for ln in wrap(beat, f, 800):
            w = int(d.textlength(ln, font=f))
            x = (W - w) // 2 - 20
            d.rounded_rectangle((x - 26, y - 14, x + w + 26, y + 84), 20, fill=(255, 255, 255, 255))
            d.text((x, y - 2), ln, font=f, fill=(0, 0, 0))
            y += 98
        y += 44
        layers.append(layer)
    return layers


def loop_frames(post: dict, seed: int, total: float):
    kind = post["scene"]
    bokeh = None
    if kind == "night":
        bokeh = Bokeh(seed, [(255, 186, 96), (255, 226, 170), (120, 170, 255), (255, 110, 90)], 34, (0.15, 1.0))
    elif kind == "dusk":
        bokeh = Bokeh(seed, [(255, 196, 110), (255, 230, 180)], 18, (0.72, 1.0))
    layers = text_layers(post["beats"])
    starts = [0.2] if len(layers) == 1 else [0.2, max(2.2, total * 0.38)]
    for k in range(int(total * FPS)):
        t = k / FPS
        im = scene_frame(kind, seed, bokeh, t, total).convert("RGBA")
        for layer, s in zip(layers, starts):
            a = min(1.0, max(0.0, (t - s) / 0.25))
            if a >= 1:
                im.alpha_composite(layer)
            elif a > 0:
                faded = layer.copy()
                faded.putalpha(layer.getchannel("A").point(lambda v, a=a: int(v * a)))
                im.alpha_composite(faded)
        yield im


def breathe_frames(post: dict, total: float):
    base = Image.new("RGBA", (W, H), (13, 13, 15, 255))
    for layer in text_layers(post["beats"]):
        base.alpha_composite(layer.transform((W, H), Image.AFFINE, (1, 0, 0, 0, 1, 170)))
    words = ["Breathe in", "Hold", "Breathe out", "Hold"]
    cx, cy = W // 2 - 20, 1000
    for k in range(int(total * FPS)):
        t = k / FPS
        cyc = t % 16
        step = int(cyc // 4)
        u = (cyc % 4) / 4
        ease = 0.5 - 0.5 * math.cos(math.pi * u)
        scale = [ease, 1, 1 - ease, 0][step]
        r = int(170 + 190 * scale)
        im = base.copy()
        d = ImageDraw.Draw(im)
        d.ellipse((cx - 360, cy - 360, cx + 360, cy + 360), outline=(70, 70, 76), width=4)
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(10, 132, 255))
        d.text((cx, cy - 34), words[step], font=font(62, "Bold"), fill=(255, 255, 255), anchor="mm")
        d.text((cx, cy + 46), str(4 - int(cyc % 4)), font=font(70, "Heavy"), fill=(255, 255, 255), anchor="mm")
        yield im


def render_video(post: dict, seed: int, folder: pathlib.Path) -> None:
    import video as V  # the kit's encoder and original score

    if post["scene"] == "breathe":
        total, frames = 32.0, breathe_frames(post, 32.0)
    else:
        words = sum(len(b.split()) for b in post["beats"])
        total = max(6.0, min(11.0, 3.0 + words * 0.34))
        frames = loop_frames(post, seed, total)
    V.encode(frames, total, total - 1.0, folder / f"{post['id']}.mp4")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--carousels", action="store_true")
    args = ap.parse_args()
    only = set(filter(None, args.only.split(",")))
    for i, post in enumerate(P.POSTS):
        if only and post["id"] not in only:
            continue
        folder = OUT / post["id"]
        folder.mkdir(parents=True, exist_ok=True)
        (folder / "caption.txt").write_text(caption_txt(post))
        if post["kind"] == "carousel":
            for n, im in enumerate(carousel(post), 1):
                im.save(folder / f"{n}.jpg", quality=92)
        elif not args.carousels:
            render_video(post, 100 + i, folder)
        print(post["id"], flush=True)


if __name__ == "__main__":
    main()
