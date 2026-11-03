#!/usr/bin/env python3
"""Build the Sober social kit: 42 carousels, Instagram crops, YouTube slideshow Shorts, profile art.

    python3 build_kit.py                 # everything, into iCloud "Sober Social Kit"
    python3 build_kit.py --only A1,D2    # just these posts (QA)
    python3 build_kit.py --no-video      # skip the Shorts (they take about 10 s each)

Slides are 1080x1920 JPEGs inside the TikTok safe area, in the app's D1 "Slow morning"
look (cream, moss, serif italic numerals). Screenshots are the real 1.3.2 captures.
Posts live in posts.py; the posting plan is README.md.
"""

from __future__ import annotations

import argparse
import csv
import functools
import pathlib
import random
import shutil
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy.io import wavfile

import posts as P

HERE = pathlib.Path(__file__).resolve().parent
GROWTH = pathlib.Path.home() / "ios/growth"
sys.path.insert(0, str(GROWTH / "animated-shorts-2026-10-27"))
sys.path.insert(0, str(GROWTH / "social-autopost"))
import ig_crop  # noqa: E402
import render as R  # noqa: E402

CAPS = pathlib.Path.home() / "ios/appstore-screenshots/captures/sober/refresh-20260916"
ICON = HERE.parents[2] / "Sober/Assets.xcassets/AppIcon.appiconset/icon_1024.png"
ICLOUD = pathlib.Path.home() / "Library/Mobile Documents/com~apple~CloudDocs/Sober Social Kit"
STORE = "https://apps.apple.com/us/app/id6768869215?pt=128748779&ct={ct}&mt=8"

W, H = 1080, 1920
SAFE = (60, 150, 950, 1500)  # left, top, right, bottom: clear of TikTok's side rail and caption
CX = (SAFE[0] + SAFE[2]) // 2
FONT, SERIF = "/System/Library/Fonts/SFNS.ttf", "/System/Library/Fonts/NewYork.ttf"

CREAM, CARD, INK = (246, 239, 224), (255, 253, 249), (26, 26, 24)
MOSS, SAND, MUTED = (47, 91, 69), (196, 156, 108), (91, 86, 76)
SKIES = [(212, 226, 231), (214, 228, 214), (238, 222, 196), (240, 216, 206), (222, 218, 236)]

SHOTS = {
    "home": "01-home.png", "timeline": "02-timeline-current.png",
    "journal": "04-journal-current.png", "species": "05-species-picker.png", "milestones": "06-progress-milestones.png",
}
# The Home bonsai in raw 1206x2622 capture pixels, clear of the "Refined" and "Switch" chips.
TREE = ("01-home.png", (50, 730, 1150, 1785))
SLOTS = ["06:30", "11:30", "17:30"]
SLOT_NAMES = ["1 Morning", "2 Midday", "3 Evening"]


# ---------------------------------------------------------------- drawing

@functools.cache
def font(size: int, weight: str = "Bold", serif: bool = False, italic: bool = False) -> ImageFont.FreeTypeFont:
    path = "/System/Library/Fonts/NewYorkItalic.ttf" if italic else (SERIF if serif else FONT)
    f = ImageFont.truetype(path, size)
    try:
        f.set_variation_by_name(weight)
    except Exception:  # noqa: BLE001
        pass
    return f


def wrap(d: ImageDraw.ImageDraw, text: str, f, width: int) -> list[str]:
    lines: list[str] = []
    for para in text.split("\n"):
        cur = ""
        for word in para.split():
            trial = f"{cur} {word}".strip()
            if d.textlength(trial, font=f) <= width or not cur:
                cur = trial
            else:
                lines.append(cur)
                cur = word
        lines.append(cur)
    return lines


def rounded(img: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, img.width - 1, img.height - 1), radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def shadow(base: Image.Image, img: Image.Image, xy: tuple[int, int], blur: int = 22, alpha: int = 55,
           drop: int = 12) -> None:
    pad = blur * 3
    sh = Image.new("RGBA", (img.width + pad * 2, img.height + pad * 2), (0, 0, 0, 0))
    sh.paste((60, 40, 20, 255), (pad, pad), img.getchannel("A").point(lambda v: v * alpha // 255))
    base.alpha_composite(sh.filter(ImageFilter.GaussianBlur(blur)), (xy[0] - pad, xy[1] - pad + drop))
    base.alpha_composite(img, xy)


@functools.cache
def _morning(seed: int) -> Image.Image:
    """A soft morning sky settling into the app's cream, with a low sun glow and paper grain."""
    rng = np.random.default_rng(seed)
    sky = np.array(SKIES[seed % len(SKIES)], float)
    t = np.clip(np.linspace(0, 1, H) / 0.85, 0, 1)[:, None, None]
    img = sky * (1 - t) + np.array(CREAM, float) * t
    img = np.broadcast_to(img, (H, W, 3)).copy()
    yy, xx = np.mgrid[0:H, 0:W]
    sx, sy = rng.uniform(0.2, 0.8) * W, rng.uniform(0.55, 0.75) * H
    glow = np.exp(-(((xx - sx) / 700) ** 2 + ((yy - sy) / 520) ** 2))
    img += glow[..., None] * np.array([18, 12, 2])
    img += np.kron(rng.normal(0, 2.4, (H // 2, W // 2)), np.ones((2, 2)))[:H, :W, None]
    return Image.fromarray(np.clip(img, 0, 255).astype("uint8")).convert("RGBA")


def background(seed: int) -> Image.Image:
    return _morning(seed).copy()


def balanced(d: ImageDraw.ImageDraw, text: str, f, width: int) -> list[str]:
    """Wrap at the narrowest width that keeps the same line count, so no line is left as an orphan."""
    n = len(wrap(d, text, f, width))
    while width > 300 and len(wrap(d, text, f, width - 20)) == n:
        width -= 20
    return wrap(d, text, f, width)


def text_boxes(im: Image.Image, lines: list[str], f, center_y: int, pad: int = 26) -> int:
    """TikTok's native caption look: ink text on white rounded boxes."""
    d = ImageDraw.Draw(im)
    lh = f.size + 24
    y = center_y - len(lines) * lh // 2
    for line in lines:
        w = d.textlength(line, font=f)
        x = CX - w / 2
        d.rounded_rectangle((x - pad, y, x + w + pad, y + lh + 2), 18, fill=(255, 255, 255))
        d.text((x, y + 6), line, font=f, fill=INK)
        y += lh
    return y


def pill(im: Image.Image, label: str, y: int) -> None:
    d = ImageDraw.Draw(im)
    f = font(38, "Semibold")
    w = d.textlength(label, font=f)
    d.rounded_rectangle((CX - w / 2 - 26, y, CX + w / 2 + 26, y + 64), 32, fill=(22, 22, 22))
    d.text((CX, y + 32), label, font=f, fill=(255, 255, 255), anchor="mm")


@functools.cache
def tree() -> Image.Image:
    name, box = TREE
    return Image.open(CAPS / name).convert("RGB").crop(box)


def hook_slide(post: dict, seed: int, swipe: bool = True) -> Image.Image:
    im = background(seed)
    d = ImageDraw.Draw(im)
    f = font(74)
    y = text_boxes(im, balanced(d, post["hook"], f, 800), f, 400)
    if swipe:
        pill(im, "swipe →", y + 30)
    t = tree()
    tw = 740
    t = rounded(t.resize((tw, int(t.height * tw / t.width)), Image.LANCZOS), 48)
    shadow(im, t, (CX - tw // 2, min(y + 140, SAFE[3] - t.height)), alpha=60)
    return im.convert("RGB")


def card_slide(seed: int, text: str) -> Image.Image:
    """A warm-white card. A line written "Day 3|text" gets "Day 3" as a moss serif italic kicker."""
    im = background(seed)
    d = ImageDraw.Draw(im)
    inner = SAFE[2] - SAFE[0] - 120
    body, kick = font(58, "Semibold"), font(70, "Medium", italic=True)
    blocks: list[tuple[str, str]] = []
    for line in text.split("\n"):
        k, _, b = line.rpartition("|")
        blocks.append((k, b))
    rows: list[tuple[str, object]] = []
    for i, (k, b) in enumerate(blocks):
        if i:
            rows.append(("gap", 30))
        if k:
            rows.append(("kick", k))
        rows += [("body", ln) for ln in wrap(d, b, body, inner)]
    height = {"kick": kick.size + 18, "body": body.size + 22}
    card_h = sum(v if kind == "gap" else height[kind] for kind, v in rows) + 120
    top = max(SAFE[1] + 40, (SAFE[1] + SAFE[3]) // 2 - card_h // 2 - 40)
    card = Image.new("RGBA", (SAFE[2] - SAFE[0], card_h), (0, 0, 0, 0))
    ImageDraw.Draw(card).rounded_rectangle((0, 0, card.width - 1, card_h - 1), 44, fill=CARD + (250,))
    shadow(im, card, (SAFE[0], top))
    y = top + 60
    for kind, v in rows:
        if kind == "gap":
            y += v
            continue
        d.text((SAFE[0] + 60, y), v, font=kick if kind == "kick" else body, fill=MOSS if kind == "kick" else INK)
        y += height[kind]
    return im.convert("RGB")


def badge(im: Image.Image, top: int) -> None:
    d = ImageDraw.Draw(im)
    icon = rounded(Image.open(ICON).convert("RGB").resize((120, 120), Image.LANCZOS), 27)
    nf, sf = font(44), font(30, "Regular")
    name, sub = P.APP, "Free to start on the App Store · I made it"
    tw = max(d.textlength(name, font=nf), d.textlength(sub, font=sf))
    x = int(CX - (120 + 26 + tw) / 2)
    shadow(im, icon, (x, top), blur=10, alpha=60, drop=5)
    d.text((x + 146, top + 14), name, font=nf, fill=INK)
    d.text((x + 146, top + 72), sub, font=sf, fill=MUTED)


def app_slide(text: str, shots: tuple[str, str]) -> Image.Image:
    im = Image.new("RGBA", (W, H), CREAM + (255,))
    d = ImageDraw.Draw(im)
    f = font(54, "Semibold")
    y = SAFE[1] + 40
    for line in wrap(d, text, f, SAFE[2] - SAFE[0] - 20):
        d.text((CX, y), line, font=f, fill=INK, anchor="mt")
        y += f.size + 14
    badge_top = SAFE[3] - 150
    sw, gap = 425, 36
    shot_top = y + 50
    shot_h = badge_top - 50 - shot_top
    for i, key in enumerate(shots):
        s = Image.open(CAPS / SHOTS[key]).convert("RGB")
        s = s.resize((sw, int(s.height * sw / s.width)), Image.LANCZOS).crop((0, 0, sw, shot_h))
        shadow(im, rounded(s, 36), (CX - sw - gap // 2 + i * (sw + gap), shot_top), alpha=70)
    badge(im, badge_top)
    return im.convert("RGB")


def slides(post: dict, seed: int) -> list[Image.Image]:
    return [hook_slide(post, seed), card_slide(seed, post["s2"]), card_slide(seed, post["s3"]),
            app_slide(post["s4"], post["shots"]), card_slide(seed, post["s5"])]


# ---------------------------------------------------------------- profile art

def avatar(out: pathlib.Path) -> None:
    Image.open(ICON).convert("RGB").resize((1024, 1024), Image.LANCZOS).save(out / "avatar.png")


def banner(out: pathlib.Path) -> None:
    """YouTube banner, 2560x1440; everything sits in the 1546x423 area every device shows."""
    bw, bh = 2560, 1440
    sky = np.array(SKIES[0], float)
    t = np.linspace(0, 1, bh)[:, None, None]
    img = np.broadcast_to(sky * (1 - t) + np.array(CREAM, float) * t, (bh, bw, 3))
    im = Image.fromarray(img.astype("uint8")).convert("RGBA")
    d = ImageDraw.Draw(im)
    icon = rounded(Image.open(ICON).convert("RGB").resize((260, 260), Image.LANCZOS), 58)
    nf, sf = font(150, "Medium", italic=True), font(56, "Semibold")
    name, sub = "Sober", "A bonsai that grows with every sober day"
    tw = max(d.textlength(name, font=nf), d.textlength(sub, font=sf))
    x = int(bw / 2 - (260 + 60 + tw) / 2)
    shadow(im, icon, (x, bh // 2 - 130), blur=16, alpha=50)
    d.text((x + 320, bh // 2 - 20), name, font=nf, fill=MOSS, anchor="ls")
    d.text((x + 320, bh // 2 + 70), sub, font=sf, fill=INK, anchor="ls")
    im.convert("RGB").save(out / "youtube-banner.jpg", quality=92)


# ---------------------------------------------------------------- captions

def cta_variant(post: dict) -> str:
    same = [p["id"] for p in P.POSTS if p["fmt"] == post["fmt"]]
    return "comment" if same.index(post["id"]) % 2 == 0 else "name"


def caption_txt(post: dict, cta: str) -> str:
    q = P.QUESTIONS[post["fmt"]]
    tags = " ".join(P.TAGS)
    safety = f"\n\n{P.SAFETY}" if post["fmt"] in "AF" else ""
    yt_title = f"{post['hook']} #shorts"[:100]
    return (
        f"TITLE (photo mode title field):\n{post['hook']}\n\n"
        f"TIKTOK CAPTION (paste as is):\n{post['caption']} {q}\n\n{P.CTAS[cta]}{safety}\n\n{tags}\n\n"
        f"INSTAGRAM CAPTION (paste as is):\n{post['caption']} {q}\n\n"
        f"The app on slide 4 is {P.APP}. I built it. Link in bio, or search \"{P.SEARCH}\" on the App Store.{safety}\n\n{tags}\n\n"
        f"YOUTUBE TITLE:\n{yt_title}\n\n"
        f"YOUTUBE DESCRIPTION:\n{post['caption']} {q}\n\n"
        f"I built {P.APP}, a day counter with a bonsai that grows every sober day. Free to start: "
        f"{STORE.format(ct='yt-sober')}{safety}\n\n{tags}\n\n"
        f"PINNED COMMENT (post it yourself, then pin):\n{P.PINNED}\n\n"
        f"REPLY to every \"app\" or \"name?\" comment:\n{P.REPLY}\n\n"
        f"BEFORE POSTING (TikTok): More options > Disclose post content > Your brand.\n"
        f"SOUND (Commercial Music Library): {P.SOUNDS[post['sound']]}\n\n"
        f"FORMAT: {post['fmt']} {P.FORMATS[post['fmt']]}   CTA: {cta}\n"
    )


# ---------------------------------------------------------------- video

def short(frames: list[pathlib.Path], out: pathlib.Path, hold: float = 3.5, fade: float = 0.35) -> None:
    """Slides into a YouTube Short under the engine's original synthesized score; under 9.5 MB."""
    n = len(frames)
    total = n * hold - (n - 1) * fade
    with tempfile.TemporaryDirectory() as tmp:
        wav = pathlib.Path(tmp) / "score.wav"
        buf = R.score(total, max(total - 1.6, total * 0.85))[: int(total * R.SR)]
        wavfile.write(wav, R.SR, (0.6 * buf / (np.abs(buf).max() + 1e-9) * 32767).astype(np.int16))
        cmd = ["ffmpeg", "-loglevel", "error", "-y"]
        for fr in frames:
            cmd += ["-loop", "1", "-t", f"{hold}", "-framerate", "30", "-i", str(fr)]
        cmd += ["-i", str(wav)]
        chains = [f"[{i}:v]setsar=1,format=yuv420p[s{i}]" for i in range(n)]
        last = "s0"
        for i in range(1, n):
            chains.append(f"[{last}][s{i}]xfade=transition=fade:duration={fade}:offset={i * (hold - fade):.2f}[x{i}]")
            last = f"x{i}"
        kbps = min(int(9.0 * 8 * 1024 / total - 160), 6000)
        cmd += ["-filter_complex", ";".join(chains), "-map", f"[{last}]", "-map", f"{n}:a", "-c:v", "libx264",
                "-b:v", f"{kbps}k", "-maxrate", f"{kbps}k", "-bufsize", f"{2 * kbps}k", "-c:a", "aac", "-b:a", "128k",
                "-shortest", "-movflags", "+faststart", str(out)]
        subprocess.run(cmd, check=True)


# ---------------------------------------------------------------- main

def schedule() -> list[dict]:
    by_fmt = {k: [p for p in P.POSTS if p["fmt"] == k] for k in P.FORMATS}
    return [by_fmt[k][r] for r in range(6) for k in P.FORMATS]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(ICLOUD))
    ap.add_argument("--only", help="comma-separated post ids")
    ap.add_argument("--no-video", action="store_true")
    args = ap.parse_args()
    out = pathlib.Path(args.out)
    only = set(args.only.split(",")) if args.only else None
    out.mkdir(parents=True, exist_ok=True)
    if not only:
        for child in [*out.glob("Day *"), out / "Instagram", out / "YouTube Shorts"]:
            shutil.rmtree(child, ignore_errors=True)
    (out / "Instagram").mkdir(exist_ok=True)
    (out / "YouTube Shorts").mkdir(exist_ok=True)
    rows = []
    for i, post in enumerate(schedule()):
        day, slot = i // 3 + 1, i % 3
        cta = cta_variant(post)
        rows.append({"day": day, "slot": SLOT_NAMES[slot], "time_pt": SLOTS[slot], "post": post["id"],
                     "format": f"{post['fmt']} {P.FORMATS[post['fmt']]}", "cta": cta, "hook": post["hook"],
                     "tiktok": "", "instagram": "", "youtube": "", "views_72h": "", "saves": "",
                     "app_comments": "", "call": ""})
        if only and post["id"] not in only:
            continue
        folder = out / f"Day {day:02d}" / f"{SLOT_NAMES[slot]} - {post['id']} {P.FORMATS[post['fmt']]}"
        folder.mkdir(parents=True, exist_ok=True)
        paths = []
        for n, s in enumerate(slides(post, i), 1):
            s.save(folder / f"{n}.jpg", quality=92)
            paths.append(folder / f"{n}.jpg")
        (folder / "caption.txt").write_text(caption_txt(post, cta))
        ig = out / "Instagram" / post["id"]
        ig.mkdir(exist_ok=True)
        for p in paths:
            ig_crop.to_ig(p).save(ig / p.name, quality=92)
        if not args.no_video:
            with tempfile.TemporaryDirectory() as tmp:
                cover = pathlib.Path(tmp) / "0.jpg"
                hook_slide(post, i, swipe=False).save(cover, quality=95)
                short([cover, *paths[1:]], out / "YouTube Shorts" / f"{post['id']}.mp4")
        print(post["id"], flush=True)
    if not only:
        with open(out / "Tracker.csv", "w", newline="") as fh:
            w = csv.DictWriter(fh, fieldnames=list(rows[0]))
            w.writeheader()
            w.writerows(rows)
        prof = out / "Profile"
        prof.mkdir(exist_ok=True)
        avatar(prof)
        banner(prof)
        shutil.copy(HERE / "profile.txt", prof / "profile.txt")
        shutil.copy(HERE / "README.md", out / "Posting guide.md")
    print(f"wrote {len(only) if only else len(rows)} posts to {out}")


if __name__ == "__main__":
    main()
