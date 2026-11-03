#!/usr/bin/env python3
"""Build experiment wave 2 (posts2.py) into iCloud "Sober Social Kit/Wave 2".

    ./frames.sh                    # once: the app's real bonsai renders into frames/
    python3 build_v2.py            # carousels, short posts and the Dry January series
    python3 build_v2.py --only K3,J07

Videos are built by video.py. Slides reuse build_kit.py's look; the hook slide shows the
app's own bonsai at the post's day count instead of the Home screenshot.
"""

from __future__ import annotations

import argparse
import functools
import pathlib
import shutil

from PIL import Image, ImageDraw, ImageFilter

import build_kit as K
import posts as P
import posts2 as P2

HERE = pathlib.Path(__file__).resolve().parent
FRAMES = HERE / "frames"
OUT = K.ICLOUD / "Wave 2"
NAMES = {"traditional": "Traditional", "cascade": "Cascade", "windswept": "Windswept", "sakura": "Cherry blossom",
         "maple": "Japanese maple", "pine": "Black pine"}


# ---------------------------------------------------------------- trees

@functools.cache
def _tree(style: str, day: int) -> Image.Image:
    im = Image.open(FRAMES / f"design600-{style}-d{day:03d}.png").convert("RGBA")
    return im.crop(im.getchannel("A").getbbox())


def tree(style: str, day: int, height: int) -> Image.Image:
    """The tree scaled so a day-365 tree of that style is `height` px tall: younger trees stay smaller."""
    full = _tree(style, 365)
    s = height / full.height
    t = _tree(style, day)
    return t.resize((max(1, int(t.width * s)), max(1, int(t.height * s))), Image.LANCZOS)


def fit(style: str, day: int, max_w: int, max_h: int) -> Image.Image:
    """The tree scaled to fill max_w x max_h, the way Home zooms in on a young tree."""
    t = _tree(style, day)
    s = min(max_w / t.width, max_h / t.height)
    return t.resize((max(1, int(t.width * s)), max(1, int(t.height * s))), Image.LANCZOS)


def plant(im: Image.Image, style: str, day: int, cx: int, base: int, height: int, label: bool = True,
          zoom: bool = True) -> None:
    """Stand a tree on a soft ground shadow with its bottom at `base`, and a "Day N" label under it.
    zoom fills the space at any age; without it the scale is fixed so growth reads across slides."""
    t = fit(style, day, 820, height) if zoom else tree(style, day, height)
    sh = Image.new("RGBA", im.size, (0, 0, 0, 0))
    w = max(t.width, 260)
    ImageDraw.Draw(sh).ellipse((cx - w * 0.55, base - 16, cx + w * 0.55, base + 22), fill=(80, 60, 30, 70))
    im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(14)))
    im.alpha_composite(t, (cx - t.width // 2, base - t.height))
    if label:
        f = K.font(64, "Medium", italic=True)
        ImageDraw.Draw(im).text((cx, base + 40), f"Day {day}", font=f, fill=K.MOSS, anchor="mt")


# ---------------------------------------------------------------- slides

def hook_tree(post: dict, seed: int, swipe: bool = True) -> Image.Image:
    im = K.background(seed)
    d = ImageDraw.Draw(im)
    f = K.font(74)
    y = K.text_boxes(im, K.balanced(d, post["hook"], f, 800), f, 400)
    if swipe:
        K.pill(im, "swipe →", y + 30)
    style, day = post["tree"]
    plant(im, style, day, K.CX, K.SAFE[3] - 110, 760, label=post["type"] in (1, 12))
    return im.convert("RGB")


def hook_grid(post: dict, seed: int) -> Image.Image:
    im = K.background(seed)
    d = ImageDraw.Draw(im)
    f = K.font(70)
    y = K.text_boxes(im, K.balanced(d, post["hook"], f, 800), f, 330)
    K.pill(im, "swipe →", y + 26)
    lf = K.font(34, "Semibold")
    for i, (style, day) in enumerate(post["grid"]):
        cx = K.SAFE[0] + 150 + (i % 3) * 295
        base = 1040 + (i // 3) * 420
        t = tree(style, day, 300)
        im.alpha_composite(t, (cx - t.width // 2, base - t.height))
        d.text((cx, base + 22), NAMES[style], font=lf, fill=K.INK, anchor="mt")
    return im.convert("RGB")


def day_slide(style: str, day: int, seed: int) -> Image.Image:
    im = K.background(seed)
    plant(im, style, day, K.CX, K.SAFE[3] - 160, 980, zoom=False)
    return im.convert("RGB")


def hook_poll(post: dict, seed: int) -> Image.Image:
    im = K.background(seed)
    d = ImageDraw.Draw(im)
    f = K.font(76)
    y = K.text_boxes(im, K.balanced(d, post["hook"], f, 800), f, 420)
    lf, of = K.font(72, "Heavy"), K.font(60, "Semibold")
    ch = 190
    for i, opt in enumerate(post["options"]):
        top = y + 90 + i * (ch + 40)
        card = Image.new("RGBA", (K.SAFE[2] - K.SAFE[0], ch), (0, 0, 0, 0))
        ImageDraw.Draw(card).rounded_rectangle((0, 0, card.width - 1, ch - 1), 44, fill=K.CARD + (250,))
        K.shadow(im, card, (K.SAFE[0], top))
        d.text((K.SAFE[0] + 70, top + ch / 2), "AB"[i], font=lf, fill=K.MOSS, anchor="lm")
        d.text((K.SAFE[0] + 170, top + ch / 2), opt, font=of, fill=K.INK, anchor="lm")
    K.pill(im, "Comment A or B", y + 90 + 2 * (ch + 40) + 20)
    style, day = post["tree"]
    plant(im, style, day, K.CX, K.SAFE[3] - 10, 330, label=False)
    return im.convert("RGB")


def hook_question(post: dict, seed: int) -> Image.Image:
    im = K.background(seed)
    d = ImageDraw.Draw(im)
    tag = K.font(40, "Semibold")
    d.text((K.CX, 300), "A question I get a lot", font=tag, fill=K.MUTED, anchor="mt")
    f = K.font(80, "Medium", serif=True)
    lines = K.balanced(d, post["hook"], f, 780)
    lh = f.size + 22
    card_h = len(lines) * lh + 130
    card = Image.new("RGBA", (K.SAFE[2] - K.SAFE[0], card_h), (0, 0, 0, 0))
    ImageDraw.Draw(card).rounded_rectangle((0, 0, card.width - 1, card_h - 1), 48, fill=K.CARD + (250,))
    K.shadow(im, card, (K.SAFE[0], 380))
    y = 380 + 65
    for ln in lines:
        d.text((K.CX, y), ln, font=f, fill=K.INK, anchor="mt")
        y += lh
    K.pill(im, "swipe for the answer →", 380 + card_h + 40)
    style, day = post["tree"]
    plant(im, style, day, K.CX, K.SAFE[3] - 60, 560, label=False)
    return im.convert("RGB")


def hook_dryjan(day: int, seed: int, swipe: bool = True) -> Image.Image:
    im = K.background(seed)
    d = ImageDraw.Draw(im)
    f = K.font(72)
    y = K.text_boxes(im, ["Dry January"], f, 300)
    big = K.font(220, "Medium", italic=True)
    d.text((K.CX, y + 40), f"Day {day}", font=big, fill=K.MOSS, anchor="mt")
    if swipe:
        K.pill(im, "today's tip →", y + 330)
    plant(im, "traditional", day, K.CX, K.SAFE[3] - 40, 640, label=False)
    return im.convert("RGB")


def slides(post: dict, seed: int) -> list[Image.Image]:
    if "grid" in post:
        first = hook_grid(post, seed)
    elif "strip" in post:
        style, days = post["strip"]
        first = hook_tree({**post, "tree": (style, days[-1])}, seed)
        return [first, *[day_slide(style, d, seed) for d in days], K.app_slide(post["s4"], post["shots"]),
                K.card_slide(seed, post["s5"])]
    elif "options" in post:
        first = hook_poll(post, seed)
    elif post["type"] == 8:
        first = hook_question(post, seed)
    else:
        first = hook_tree(post, seed)
    if post.get("short"):
        return [first, K.card_slide(seed, post["s2"]), K.app_slide(post["s4"], post["shots"])]
    return [first, K.card_slide(seed, post["s2"]), K.card_slide(seed, post["s3"]),
            K.app_slide(post["s4"], post["shots"]), K.card_slide(seed, post["s5"])]


# ---------------------------------------------------------------- captions

def caption_txt(post: dict, cta: str) -> str:
    q = P2.QUESTIONS.get(post["type"], "")
    body = f"{post['caption']} {q}".strip()
    dry = post["type"] == 14 or post.get("date", "") >= "2026-12-22"
    tags = " ".join(P.TAGS + (["#dryjanuary"] if dry else []))
    safety = f"\n\n{P.SAFETY}" if post["type"] in (1, 14) else ""
    slide = "the last slide" if post.get("short") or post["type"] == 14 else "slide 4"
    ctas = {"comment": f'Comment "app" and I\'ll reply with the one on {slide} (full disclosure, I made it).',
            "name": f'The app on {slide} is {P.APP}. I built it. Search "{P.SEARCH}" on the App Store, it\'s free to start.'}
    sound = P.SOUNDS.get(post.get("sound", "calm"))
    return (
        f"TITLE (photo mode title field):\n{post['hook']}\n\n"
        f"TIKTOK CAPTION (paste as is):\n{body}\n\n{ctas[cta]}{safety}\n\n{tags}\n\n"
        f"PINNED COMMENT (post it yourself, then pin):\n{P.PINNED.replace('slide 4', slide)}\n\n"
        f"BEFORE POSTING (TikTok): More options > Disclose post content > Your brand.\n"
        f"SOUND (Commercial Music Library): {sound}\n\n"
        f"TYPE: {post['type']} {P2.TYPES[post['type']]}   CTA: {cta}   SCHEDULE AFTER: {post.get('date', 'any')}\n"
    )


def dryjan_posts() -> list[dict]:
    out = []
    for n, tip in enumerate(P2.DRY_JAN, 1):
        out.append({"id": f"J{n:02d}", "type": 14, "day": n, "date": f"2027-01-{n:02d}", "sound": "calm",
                    "hook": f"Dry January, day {n}", "tip": tip,
                    "caption": f"Dry January, day {n}. Today's tip: {tip}"})
    return out


def dryjan_slides(post: dict, seed: int) -> list[Image.Image]:
    return [hook_dryjan(post["day"], seed), K.card_slide(seed, f"Today|{post['tip']}"),
            K.app_slide("I built a day counter where a bonsai grows with every sober day.", ("home", "milestones"))]


def all_posts() -> list[dict]:
    return P2.POSTS2 + dryjan_posts()


def folder_for(post: dict) -> pathlib.Path:
    t = post["type"]
    name = post["hook"].replace("/", "-").replace('"', "")[:60]
    return OUT / f"{t:02d} {P2.TYPES[t]}" / f"{post['id']} {name}"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only")
    args = ap.parse_args()
    only = set(args.only.split(",")) if args.only else None
    for i, post in enumerate(all_posts()):
        if only and post["id"] not in only:
            continue
        seed = 100 + i
        folder = folder_for(post)
        shutil.rmtree(folder, ignore_errors=True)
        folder.mkdir(parents=True)
        made = dryjan_slides(post, seed) if post["type"] == 14 else slides(post, seed)
        for n, s in enumerate(made, 1):
            s.save(folder / f"{n}.jpg", quality=92)
        (folder / "caption.txt").write_text(caption_txt(post, "comment" if i % 2 == 0 else "name"))
        print(post["id"], len(made), flush=True)


if __name__ == "__main__":
    main()
