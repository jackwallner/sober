#!/usr/bin/env python3
"""Android launcher icon from the iOS app icon (no redrawing, so they never drift).

The iOS icon is a flat moss square with the crossed glass. The adaptive icon
uses that moss as its background layer and the glyph, keyed off the moss, as
the foreground: the iOS square maps onto the 72dp visible area of the 108dp
canvas, which keeps the glyph well inside the safe zone. A white silhouette
serves as the themed-icon monochrome layer. Also writes the 512px Play icon.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Sober/Assets.xcassets/AppIcon.appiconset/icon_1024.png"
RES = ROOT / "android/app/src/main/res"
DENSITIES = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}


def glyph(icon: Image.Image, monochrome: bool) -> Image.Image:
    """The icon with its flat background keyed to transparency (soft edges kept)."""
    bg = icon.getpixel((8, 8))
    out = Image.new("RGBA", icon.size)
    src = icon.load()
    dst = out.load()
    for y in range(icon.height):
        for x in range(icon.width):
            r, g, b = src[x, y]
            distance = max(abs(r - bg[0]), abs(g - bg[1]), abs(b - bg[2]))
            alpha = min(255, distance * 3)
            dst[x, y] = (255, 255, 255, alpha) if monochrome else (r, g, b, alpha)
    return out


def layer(art: Image.Image, px: int) -> Image.Image:
    canvas = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    inner = round(px * 72 / 108)
    canvas.paste(art.resize((inner, inner), Image.LANCZOS), ((px - inner) // 2, (px - inner) // 2))
    return canvas


def main() -> None:
    icon = Image.open(SOURCE).convert("RGB")
    bg = icon.getpixel((8, 8))
    color, white = glyph(icon, False), glyph(icon, True)
    for name, px in DENSITIES.items():
        folder = RES / f"mipmap-{name}"
        folder.mkdir(parents=True, exist_ok=True)
        layer(color, px).save(folder / "ic_launcher_foreground.png")
        layer(white, px).save(folder / "ic_launcher_monochrome.png")
        for stale in folder.glob("ic_launcher_background.png"):
            stale.unlink()
    values = RES / "values"
    (values / "ic_launcher_background.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        f'    <color name="ic_launcher_background">#{bg[0]:02X}{bg[1]:02X}{bg[2]:02X}</color>\n</resources>\n'
    )
    xml = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
"""
    anydpi = RES / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    (anydpi / "ic_launcher.xml").write_text(xml)
    (anydpi / "ic_launcher_round.xml").write_text(xml)
    assets = ROOT / "android/play-assets"
    assets.mkdir(parents=True, exist_ok=True)
    icon.resize((512, 512), Image.LANCZOS).save(assets / "icon-512.png")
    print("wrote adaptive icon layers and play-assets/icon-512.png")


if __name__ == "__main__":
    main()
