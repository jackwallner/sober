#!/usr/bin/env python3
"""Composite raw Android captures into Google Play screenshots and the feature graphic.

Same look and copy as the App Store set (fastlane/screenshots/en-US): an
eyebrow, a two-line serif headline and a subtitle over alternating cream and
moss panels, with the real capture below. Play rejects anything longer than
2:1, so frames are 1080x1920. Reads android/play-assets/raw/ (1080x2400
captures from the debug build) and writes android/play-assets/screenshots/
and android/play-assets/feature-graphic.png.

Usage: python3 scripts/play_screenshot_compositor.py
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "android" / "play-assets"
RAW = ASSETS / "raw"
OUT = ASSETS / "screenshots"
FONTS = ROOT / "android" / "app" / "src" / "main" / "res" / "font"

W, H = 1080, 1920
CREAM = (244, 238, 225)
MOSS = (24, 61, 48)
INK = (26, 26, 24)
INK_SOFT = (82, 78, 70)
GREEN = (47, 91, 69)
GOLD = (212, 170, 80)
CREAM_TEXT = (240, 234, 220)


@dataclass
class Shot:
    raw: str
    headline: tuple[str, str]
    subtitle: str
    dark: bool


SHOTS = [
    Shot("01-home.png", ("Your sober days,", "at a glance."), "Counter, check-in, and calendar without the noise.", False),
    Shot("02-species.png", ("A garden that", "grows with you."), "Every alcohol-free day changes your bonsai.", True),
    Shot("03-progress.png", ("See what drinking", "used to cost."), "Track the money and calories you keep.", False),
    Shot("04-health.png", ("Know what recovery", "is changing."), "Evidence-linked milestones, day by day.", True),
    Shot("06-craving.png", ("Ride out", "a craving."), "A few minutes of guided breathing, free.", False),
    Shot("05-journal.png", ("Private. No account.", "Your data stays yours."), "A journal and daily check-ins only you can see.", True),
    Shot("07-paywall.png", ("Try every Bloom+ tool", "free for 7 days."), "Yearly or monthly. Pay nothing today.", False),
]


def font(name: str, size: int, weight: int, opsz: int | None = None) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(str(FONTS / name), size)
    axes = {"Weight": weight}
    if opsz:
        axes["Optical size"] = opsz
    try:
        names = [a.decode() if isinstance(a, bytes) else a for a in f.get_variation_axes()]
        f.set_variation_by_axes([axes.get(a["name"].decode() if isinstance(a["name"], bytes) else a["name"], a["default"]) for a in f.get_variation_axes()])
    except Exception:
        pass
    return f


def panel(dark: bool) -> Image.Image:
    img = Image.new("RGB", (W, H), MOSS if dark else CREAM)
    d = ImageDraw.Draw(img)
    accent = GOLD if dark else GREEN
    # The App Store set's arc and dots.
    d.arc([(700, -560), (1400, 140)], start=90, end=180, fill=accent, width=4)
    d.ellipse([(990, 28), (1014, 52)], outline=accent, width=4)
    d.ellipse([(80, 1800), (104, 1824)], outline=accent, width=4)
    return img


def render(shot: Shot) -> Path:
    img = panel(shot.dark)
    d = ImageDraw.Draw(img)
    accent = GOLD if shot.dark else GREEN
    text = CREAM_TEXT if shot.dark else INK
    soft = (205, 214, 205) if shot.dark else INK_SOFT
    d.ellipse([(52, 74), (90, 112)], outline=accent, width=4)
    d.text((96, 70), "SOBER", font=font("nunito.ttf", 30, 600), fill=accent)
    d.text((96, 108), "PRIVATE SOBRIETY TRACKER", font=font("nunito.ttf", 21, 500), fill=soft)
    head = font("newsreader.ttf", 96, 500, 72)
    for i, line in enumerate(shot.headline):
        d.text((84, 170 + i * 104), line, font=head, fill=text)
    d.text((88, 398), shot.subtitle, font=font("nunito.ttf", 38, 400), fill=soft)

    raw = Image.open(RAW / shot.raw).convert("RGB")
    if raw.size != (1080, 2400):
        raise ValueError(f"{shot.raw} is {raw.size}, expected 1080x2400")
    top = 500
    sh = H - top - 64
    sw = round(sh * raw.width / raw.height)
    scaled = raw.resize((sw, sh), Image.LANCZOS)
    left = (W - sw) // 2
    radius = 46
    mask = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle([(0, 0), (sw - 1, sh - 1)], radius=radius, fill=255)
    shadow = Image.new("RGBA", (sw + 120, sh + 120), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([(60, 70), (sw + 60, sh + 70)], radius=radius, fill=(0, 0, 0, 110 if shot.dark else 60))
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    img.paste(shadow, (left - 60, top - 60), shadow)
    img.paste(scaled, (left, top), mask)
    ImageDraw.Draw(img).rounded_rectangle([(left, top), (left + sw - 1, top + sh - 1)], radius=radius, outline=(0, 0, 0) if not shot.dark else (60, 90, 78), width=2)
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / shot.raw.replace(".png", ".jpg")
    img.save(path, "JPEG", quality=92)
    return path


def feature_graphic() -> Path:
    fw, fh = 1024, 500
    img = Image.new("RGB", (fw, fh), MOSS)
    d = ImageDraw.Draw(img)
    icon = Image.open(ROOT / "Sober/Assets.xcassets/AppIcon.appiconset/icon_1024.png").convert("RGB").resize((150, 150), Image.LANCZOS)
    m = Image.new("L", (150, 150), 0)
    ImageDraw.Draw(m).rounded_rectangle([(0, 0), (149, 149)], radius=34, fill=255)
    img.paste(icon, (70, 90), m)
    d.text((70, 262), "Sober", font=font("newsreader.ttf", 84, 500, 72), fill=CREAM_TEXT)
    tagline = font("nunito.ttf", 32, 500)
    d.text((72, 362), "Count sober days.", font=tagline, fill=(205, 214, 205))
    d.text((72, 404), "Grow a bonsai.", font=tagline, fill=(205, 214, 205))
    tree = Image.open(RAW / "01-home.png").convert("RGB").crop((40, 610, 1040, 1585))
    tree = tree.resize((round(tree.width * 420 / tree.height), 420), Image.LANCZOS)
    tm = Image.new("L", tree.size, 0)
    ImageDraw.Draw(tm).rounded_rectangle([(0, 0), (tree.width - 1, tree.height - 1)], radius=30, fill=255)
    img.paste(tree, (fw - tree.width - 60, (fh - tree.height) // 2), tm)
    path = ASSETS / "feature-graphic.png"
    img.save(path, "PNG")
    return path


def main() -> None:
    for shot in SHOTS:
        print(render(shot))
    print(feature_graphic())


if __name__ == "__main__":
    main()
