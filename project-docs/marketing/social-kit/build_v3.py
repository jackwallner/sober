#!/usr/bin/env python3
"""Build experiment wave 3 (posts3.py) into iCloud "Sober Social Kit/Wave 3".

    python3 build_v3.py              # every post, plus a "no app" cut of each post with an app slide
    python3 build_v3.py --only Nt1,L1

Looks: morning (the kit's own), night (dusk to dark, cream serif, a glowing tree) and plain
(lazy text on a flat colour). Trees are the app's real renders (frames.sh).
"""

from __future__ import annotations

import argparse
import functools
import pathlib
import shutil

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import build_kit as K
import build_v2 as B
import posts3 as P3

OUT = K.ICLOUD / "Wave 3"
CREAMY, SANDY, DIM = (246, 239, 224), (214, 178, 128), (190, 184, 170)
PLAINS = [(236, 226, 206), (216, 226, 210), (238, 220, 212), (224, 222, 236)]


# ---------------------------------------------------------------- backgrounds

@functools.cache
def _night(seed: int) -> Image.Image:
    rng = np.random.default_rng(seed)
    t = np.linspace(0, 1, K.H)[:, None, None]
    top, bottom = np.array([28, 32, 54], float), np.array([14, 30, 24], float)
    img = np.broadcast_to(top * (1 - t) + bottom * t, (K.H, K.W, 3)).copy()
    yy, xx = np.mgrid[0:K.H, 0:K.W]
    glow = np.exp(-(((xx - K.CX) / 520) ** 2 + ((yy - 1180) / 420) ** 2))
    img += glow[..., None] * np.array([46, 38, 22])
    img += np.kron(rng.normal(0, 3.2, (K.H // 2, K.W // 2)), np.ones((2, 2)))[:K.H, :K.W, None]
    stars = rng.random((K.H, K.W)) > 0.9994
    img[stars & (yy < 700)] = [230, 226, 210]
    return Image.fromarray(np.clip(img, 0, 255).astype("uint8")).convert("RGBA")


def night_bg(seed: int) -> Image.Image:
    return _night(seed).copy()


def plain_bg(seed: int) -> Image.Image:
    return Image.new("RGBA", (K.W, K.H), PLAINS[seed % len(PLAINS)] + (255,))


# ---------------------------------------------------------------- night look

def night_text(im: Image.Image, text: str, f, top: int, fill=CREAMY, width: int = 820) -> int:
    d = ImageDraw.Draw(im)
    for ln in K.balanced(d, text, f, width):
        d.text((K.CX, top), ln, font=f, fill=fill, anchor="mt")
        top += f.size + 20
    return top


def night_tree(im: Image.Image, style: str, day: int, base: int, height: int, ref: int | None = None) -> None:
    """ref: scale against that day's tree so a strip of slides shows growth; otherwise zoom to fill."""
    if ref:
        t = B._tree(style, day)
        s = height / B._tree(style, ref).height
        t = t.resize((max(1, int(t.width * s)), max(1, int(t.height * s))), Image.LANCZOS)
    else:
        t = B.fit(style, day, 760, height)
    halo = Image.new("RGBA", im.size, (0, 0, 0, 0))
    r = max(t.width, t.height) * 0.55
    ImageDraw.Draw(halo).ellipse((K.CX - r, base - t.height / 2 - r, K.CX + r, base - t.height / 2 + r),
                                 fill=(255, 226, 170, 46))
    im.alpha_composite(halo.filter(ImageFilter.GaussianBlur(90)))
    im.alpha_composite(t, (K.CX - t.width // 2, base - t.height))


def night_hook(post: dict, seed: int) -> Image.Image:
    im = night_bg(seed)
    y = night_text(im, post["hook"], K.font(82, "Medium", serif=True), 300)
    K.pill(im, "swipe →", y + 30)
    style, day = post.get("tree") or post["trees"][-1]
    night_tree(im, style, day, K.SAFE[3] - 60, 700)
    return im.convert("RGB")


def night_slide(line: str, seed: int, tree: tuple[str, int] | None = None, ref: int | None = None) -> Image.Image:
    im = night_bg(seed)
    kick, _, body = line.rpartition("|")
    y = 420 if tree else 640
    if kick:
        y = night_text(im, kick, K.font(76, "Medium", italic=True), y, fill=SANDY) + 24
    night_text(im, body, K.font(64, "Semibold"), y, width=800)
    if tree:
        night_tree(im, tree[0], tree[1], K.SAFE[3] - 60, 560, ref)
    return im.convert("RGB")


def night_close(text: str, seed: int) -> Image.Image:
    im = night_bg(seed)
    night_text(im, text, K.font(84, "Medium", italic=True), 700, fill=CREAMY)
    return im.convert("RGB")


# ---------------------------------------------------------------- plain look

def plain_slide(text: str, seed: int, size: int = 84, hook: bool = False) -> Image.Image:
    im = plain_bg(seed)
    d = ImageDraw.Draw(im)
    f = K.font(size, "Bold")
    lines = K.wrap(d, text, f, K.SAFE[2] - K.SAFE[0] - 40)
    lh = size + 22
    y = (K.SAFE[1] + K.SAFE[3]) // 2 - len(lines) * lh // 2 - 80
    for ln in lines:
        d.text((K.SAFE[0] + 20, y), ln, font=f, fill=K.INK)
        y += lh
    if hook:
        d.text((K.SAFE[0] + 20, y + 40), "swipe →", font=K.font(42, "Semibold"), fill=K.MUTED)
    return im.convert("RGB")


# ---------------------------------------------------------------- morning identity look

def morning_slide(line: str, seed: int, tree: tuple[str, int], ref: int) -> Image.Image:
    """Kicker and line up top, the tree at a fixed scale (relative to day `ref`) so it grows slide to slide."""
    im = K.background(seed)
    d = ImageDraw.Draw(im)
    kick, _, body = line.rpartition("|")
    y = 330
    if kick:
        d.text((K.CX, y), kick, font=K.font(110, "Medium", italic=True), fill=K.MOSS, anchor="mt")
        y += 150
    y = K.text_boxes(im, K.balanced(d, body, K.font(64), 800), K.font(64), y + 50)
    t = B._tree(*tree)
    s = 700 / B._tree(tree[0], ref).height
    t = t.resize((max(1, int(t.width * s)), max(1, int(t.height * s))), Image.LANCZOS)
    im.alpha_composite(t, (K.CX - t.width // 2, K.SAFE[3] - 20 - t.height))
    return im.convert("RGB")


# ---------------------------------------------------------------- posts

def slides(post: dict, seed: int, with_app: bool = True) -> list[Image.Image]:
    look, app = post["look"], post["app"] if with_app else None
    trees = post.get("trees")
    if look == "plain":
        out = [plain_slide(post["hook"], seed, 96, hook=True)]
        out += [plain_slide(s, seed) for s in post["slides"]]
        if app:
            out.append(K.app_slide(app, ("home", "milestones")))
        out.append(plain_slide(post["close"], seed, 72))
        return out
    if look == "night":
        out = [night_hook(post, seed)]
        for i, s in enumerate(post["slides"]):
            out.append(night_slide(s, seed, trees[i], trees[-1][1]) if trees else night_slide(s, seed))
        if app:
            out.append(K.app_slide(app, ("home", "milestones")))
        out.append(night_close(post["close"], seed))
        return out
    ref = trees[-1][1]
    hook = {**post, "tree": trees[-1], "type": 0}
    out = [B.hook_tree(hook, seed)]
    out += [morning_slide(s, seed, t, ref) for s, t in zip(post["slides"], trees)]
    if app:
        out.append(K.app_slide(app, ("home", "milestones")))
    out.append(K.card_slide(seed, post["close"]))
    return out


def folder_for(post: dict, with_app: bool = True) -> pathlib.Path:
    name = post["hook"].replace("/", "-").replace('"', "")[:60]
    return OUT / f"{post['id']}{'' if with_app else ' no app'} {name}"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only")
    args = ap.parse_args()
    only = set(args.only.split(",")) if args.only else None
    for i, post in enumerate(P3.POSTS3):
        if only and post["id"] not in only:
            continue
        cuts = [True, False] if post["app"] else [True]
        for with_app in cuts:
            folder = folder_for(post, with_app)
            shutil.rmtree(folder, ignore_errors=True)
            folder.mkdir(parents=True)
            made = slides(post, 500 + i, with_app)
            for n, s in enumerate(made, 1):
                s.save(folder / f"{n}.jpg", quality=92)
            print(folder.name, len(made), flush=True)


if __name__ == "__main__":
    main()
