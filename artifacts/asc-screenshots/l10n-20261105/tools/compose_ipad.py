#!/usr/bin/env python3
"""Compose 13-inch iPad store frames (2064x2752) from raw captures.

Usage: compose_ipad.py LOCALE [LOCALE ...]   (reads raw/L/ipad, copy/headers.json)
Writes out/L/ipad/appstore_ipad_0N_*.png. One header size per locale set.
"""
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

from common import headline, read_json

kit = Path(__file__).resolve().parent.parent
W, H = 2064, 2752
CREAM, GREEN = (246, 239, 224), (21, 58, 45)
FRAMES = [  # file, phone header key, raw, background, text color
    ('appstore_ipad_01_counter.png', 'appstore_preview_01_counter.png', 'home', CREAM, (17, 18, 15)),
    ('appstore_ipad_02_garden.png', 'appstore_preview_02_garden.png', 'home', GREEN, (255, 255, 255)),
    ('appstore_ipad_03_savings.png', 'appstore_preview_03_savings.png', 'savings', CREAM, (17, 18, 15)),
    ('appstore_ipad_04_recovery.png', 'appstore_preview_04_recovery.png', 'health', GREEN, (255, 255, 255)),
    ('appstore_ipad_05_private.png', 'appstore_preview_05_private.png', 'journal', CREAM, (17, 18, 15)),
    ('appstore_ipad_06_trial.png', 'appstore_preview_06_trial.png', 'bloom', GREEN, (255, 255, 255)),
]
HEADER = (150, 175, 1764, 400)
SCREEN_W, BEZEL = 1560, 20
SCREEN_H = round(SCREEN_W * H / W)
DEV_X, DEV_Y = (W - SCREEN_W) // 2 - BEZEL, 595


def rounded(size, radius, scale=3):
    mask = Image.new('L', (size[0] * scale, size[1] * scale), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] * scale - 1, size[1] * scale - 1), radius=radius * scale, fill=255)
    return mask.resize(size, Image.Resampling.LANCZOS)


def device(raw):
    dw, dh = SCREEN_W + 2 * BEZEL, SCREEN_H + 2 * BEZEL
    body = Image.new('RGB', (dw, dh), (22, 22, 22))
    body.paste(raw.convert('RGB').resize((SCREEN_W, SCREEN_H), Image.Resampling.LANCZOS), (BEZEL, BEZEL), rounded((SCREEN_W, SCREEN_H), 70))
    return body, rounded((dw, dh), 92)


def main():
    headers = read_json(kit / 'copy/headers.json')
    for locale in sys.argv[1:]:
        jobs = [{'text': headers[locale][key], 'locale': locale, 'font': '.NewYork-Regular', 'color': list(color),
                 'box': list(HEADER[2:]), 'maxSize': 175, 'minSize': 1, 'align': 'left'} for _, key, _, _, color in FRAMES]
        size = min(r['size'] for r in headline(jobs))
        with tempfile.TemporaryDirectory() as tmp:
            for i, job in enumerate(jobs):
                job.update(size=size, out=f'{tmp}/{i}.png')
            rendered = headline(jobs)
            assert all(r['fits'] for r in rendered), locale
            out = kit / 'out' / locale / 'ipad'
            out.mkdir(parents=True, exist_ok=True)
            for i, (name, _, raw_name, bg, _) in enumerate(FRAMES):
                canvas = Image.new('RGB', (W, H), bg)
                body, mask = device(Image.open(kit / 'raw' / locale / 'ipad' / f'{raw_name}.png'))
                shadow = Image.new('L', (W, H), 0)
                shadow.paste(mask.point(lambda v: v * 0.45), (DEV_X, DEV_Y + 30))
                shadow = shadow.filter(ImageFilter.GaussianBlur(40))
                canvas.paste(Image.new('RGB', (W, H), (0, 0, 0)), (0, 0), shadow)
                canvas.paste(body, (DEV_X, DEV_Y), mask)
                overlay = Image.open(f'{tmp}/{i}.png')
                canvas.paste(overlay, HEADER[:2], overlay)
                canvas.save(out / name, optimize=True)
        print(f'{locale}: size={size:g}')


if __name__ == '__main__':
    main()
