#!/usr/bin/env python3
"""Generate the Sober app icon: a single curved leaf on the moss brand gradient.

Renders at 4x supersample then downscales for clean edges. No alpha (App Store
requirement). Palette matches Theme.swift D1 'Slow morning': moss + cream.
"""
import math
from PIL import Image, ImageDraw

SS = 4                      # supersample factor
SIZE = 1024 * SS
OUT = "Sober/Assets.xcassets/AppIcon.appiconset/icon_1024.png"

# Palette (sRGB 0-255), from Theme.swift
MOSS_DARK = (40, 78, 60)        # #284E3C — deeper than brandPrimary for corners
MOSS_MID = (47, 91, 69)         # #2F5B45 brandPrimary
MOSS_LIGHT = (79, 133, 104)     # #4F8568 lighter moss
CREAM = (246, 239, 224)         # #F6EFE0
CREAM_HI = (255, 253, 249)      # warm white
VEIN = (47, 91, 69)             # moss vein on the leaf


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient_bg(size, c0, c1):
    """Diagonal top-left -> bottom-right gradient."""
    img = Image.new("RGB", (size, size), c0)
    px = img.load()
    maxd = (size - 1) * 2
    for y in range(size):
        for x in range(size):
            px[x, y] = lerp(c0, c1, (x + y) / maxd)
    return img


def leaf_polygon(cx, cy, length, max_half_w, angle_deg):
    """Pointed-oval leaf outline, tapered to a point at both ends, rotated."""
    a = math.radians(angle_deg)
    ca, sa = math.cos(a), math.sin(a)
    pts = []
    n = 220
    # right edge tip->base, then left edge base->tip
    for side in (1, -1):
        rng = range(n + 1) if side == 1 else range(n, -1, -1)
        for i in rng:
            t = i / n                      # 0 at base end, 1 at tip end
            # asymmetric taper: fuller near base, sharp tip — leaf-like
            w = math.sin(math.pi * t) ** 0.78 * max_half_w
            # slight curve to the spine for character (not mirror-symmetric)
            spine = math.sin(math.pi * t) * length * 0.06
            ly = (t - 0.5) * length
            lx = side * w + spine
            pts.append((cx + lx * ca - ly * sa, cy + lx * sa + ly * ca))
    return pts


def main():
    img = gradient_bg(SIZE, MOSS_LIGHT, MOSS_DARK)
    d = ImageDraw.Draw(img)

    cx, cy = SIZE / 2, SIZE / 2
    length = SIZE * 0.60
    half_w = SIZE * 0.185
    angle = -12  # gentle lean

    # soft drop shadow behind the leaf
    shadow = leaf_polygon(cx + SIZE * 0.012, cy + SIZE * 0.018, length, half_w, angle)
    d.polygon(shadow, fill=lerp(MOSS_DARK, (0, 0, 0), 0.25))

    leaf = leaf_polygon(cx, cy, length, half_w, angle)
    d.polygon(leaf, fill=CREAM)

    # subtle highlight sliver along one side for a painterly lift
    hi = leaf_polygon(cx - SIZE * 0.018, cy - SIZE * 0.01, length * 0.86, half_w * 0.78, angle)
    d.polygon(hi, fill=CREAM_HI)

    # midrib + a few side veins, in moss
    a = math.radians(angle)
    ca, sa = math.cos(a), math.sin(a)

    def lp(lx, ly):
        return (cx + lx * ca - ly * sa, cy + lx * sa + ly * ca)

    # midrib (follows the curved spine)
    rib = []
    n = 80
    for i in range(n + 1):
        t = i / n
        ly = (t - 0.5) * length * 0.94
        lx = math.sin(math.pi * t) * length * 0.06
        rib.append(lp(lx, ly))
    d.line(rib, fill=VEIN, width=int(SIZE * 0.012), joint="curve")

    # side veins branching off the midrib
    vw = int(SIZE * 0.007)
    for k in range(1, 6):
        t = k / 6
        ly = (t - 0.5) * length * 0.94
        lx0 = math.sin(math.pi * t) * length * 0.06
        wmax = math.sin(math.pi * t) ** 0.78 * half_w
        for side in (1, -1):
            ex = side * wmax * 0.72 + lx0
            ey = ly + length * 0.07
            d.line([lp(lx0, ly), lp(ex, ey)], fill=VEIN, width=vw, joint="curve")

    img = img.resize((1024, 1024), Image.LANCZOS)
    img.save(OUT, "PNG")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
