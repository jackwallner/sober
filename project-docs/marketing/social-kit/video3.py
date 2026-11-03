#!/usr/bin/env python3
"""Wave 3 motion loops into iCloud "Sober Social Kit/Wave 3/Loops/<id>.mp4".

    python3 video3.py              # every loop
    python3 video3.py --only E1,V3

The research pass (2026-11-02) found SoberTok's repeatable format for an account without a personal
story is a 5 to 12 second text loop with real motion, and that static-image videos risk reading as
minimally edited. So every loop has a moving tree: a slow sway from the base, a gentle push-in,
drifting particles (petals, leaves, stars or light motes) and text in TikTok's native white boxes.

Kinds: pov (wave 2's POV beats, re-cut with motion), ever ("Ever notice...?" body-signal hooks),
ask (builder "ask the room" questions), friday (dated POVs).
"""

from __future__ import annotations

import argparse
import math

import numpy as np
from PIL import Image, ImageDraw

import build_kit as K
import build_v2 as B
import build_v3 as B3
import posts2 as P2
import video as V

FPS = V.FPS
OUT = B3.OUT / "Loops"

# beats: on-screen lines, shown in order. caption: the TikTok caption body. tags: topic hashtags.
LOOPS = [
    # ------------------------------------------------------------------ Ever notice (body signals)
    {"id": "E1", "kind": "ever", "look": "night", "tree": ("pine", 90),
     "beats": ["Ever notice you wake up at 3am after a couple of drinks?",
               "Alcohol can break up the second half of the night's sleep."],
     "caption": "Many people find sleep settles within the first couple of alcohol-free weeks "
                "(source: Sleep Foundation). Does the 3am wake-up sound familiar?",
     "tags": ["#sleep", "#alcoholfree"]},
    {"id": "E2", "kind": "ever", "look": "morning", "tree": ("traditional", 90),
     "beats": ["Ever notice the anxiety the morning after drinking?",
               "There's a name for it: hangxiety. Many people say it fades alcohol-free."],
     "caption": "Hangxiety is common, and a lot of people notice calmer mornings once they take a break. "
                "What do your mornings feel like lately?",
     "tags": ["#hangxiety", "#anxiety"]},
    {"id": "E3", "kind": "ever", "look": "night", "tree": ("sakura", 60),
     "beats": ["Ever check your sleep score after two glasses of wine?",
               "Many people watch it climb in their first alcohol-free week."],
     "caption": "Your watch or ring often shows it first: resting heart rate and sleep scores. "
                "Has yours changed?",
     "tags": ["#sleepscore", "#ouraring"]},
    {"id": "E4", "kind": "ever", "look": "morning", "tree": ("maple", 45),
     "beats": ["Ever notice how puffy your face looks the morning after?",
               "Many people see it settle in the first few alcohol-free weeks."],
     "caption": "Alcohol dehydrates, and a lot of people notice the difference in the mirror once they take a break. "
                "What changed first for you?",
     "tags": ["#skincare", "#alcoholfree"]},
    {"id": "E5", "kind": "ever", "look": "morning", "tree": ("traditional", 70),
     "beats": ["Ever notice Sunday disappears after a big Saturday?",
               "Alcohol-free weekends give you the whole Sunday back."],
     "caption": "Sunday is the best day of an alcohol-free weekend. What would you do with yours?",
     "tags": ["#sundayreset", "#alcoholfree"]},
    {"id": "E6", "kind": "ever", "look": "night", "tree": ("cascade", 120),
     "beats": ["Ever add up a 'quiet' night out?",
               "Two drinks and a tip can be $30. Once a week, that's $1,560 a year."],
     "caption": "The quiet nights add up fastest. What would you do with $1,560?",
     "tags": ["#moneytips", "#alcoholfree"]},
    # ------------------------------------------------------------------ Ask the room (builder)
    {"id": "A1", "kind": "ask", "look": "night", "tree": ("windswept", 90),
     "beats": ["What did you think was normal until you stopped drinking?"],
     "caption": "I'm building a sober app, and your answers shape what I build next. What's yours?",
     "tags": ["#quitdrinking", "#soberlife"]},
    {"id": "A2", "kind": "ask", "look": "night", "tree": ("pine", 140),
     "beats": ["What got you through night 3?"],
     "caption": "Night 3 can be the hardest. Drop what helped you, someone starting today needs it.",
     "tags": ["#quitdrinking", "#soberlife"]},
    {"id": "A3", "kind": "ask", "look": "morning", "tree": ("sakura", 150),
     "beats": ["What's your go-to drink now, instead of alcohol?"],
     "caption": "Building a list for my sober app. Give me your best order.",
     "tags": ["#mocktails", "#nonalcoholic"]},
    {"id": "A4", "kind": "ask", "look": "morning", "tree": ("maple", 200),
     "beats": ["What's the best surprise about being alcohol-free?"],
     "caption": "I'm building a sober app and collecting the good parts. What surprised you?",
     "tags": ["#soberlife", "#quitdrinking"]},
    # ------------------------------------------------------------------ Dated POVs
    {"id": "F1", "kind": "friday", "look": "night", "tree": ("traditional", 60),
     "beats": ["POV: it's Friday night", "you're alcohol-free and home safe"],
     "caption": "Home, cozy and clear-headed on a Friday. Tomorrow-you says thanks.",
     "tags": ["#fridaynight", "#alcoholfree"]},
]

# Wave 2's POVs, re-cut as motion loops. Topic tags per id.
POV_TAGS = {"V1": ["#fridaynight"], "V2": ["#saturdaymorning"], "V3": ["#mocktails"], "V5": ["#cravings"],
            "V6": ["#bonsai"], "V7": ["#soberlife"], "V8": ["#sundaymorning"], "V9": ["#soberlife"],
            "V10": ["#sobermilestone"], "V12": ["#dayone"]}
for v in P2.VIDEOS:
    if v["kind"] == "pov" and v["id"] in POV_TAGS:
        LOOPS.append({"id": v["id"], "kind": "pov", "look": "night" if v["id"] in ("V1", "V5", "V9") else "morning",
                      "tree": v["tree"], "beats": v["beats"], "caption": v["caption"],
                      "tags": POV_TAGS[v["id"]] + ["#alcoholfree"]})

PARTICLES = {"sakura": (246, 186, 204), "maple": (222, 112, 52)}


class Particles:
    """Slow drifting dots: petals or leaves for blossom trees, warm light motes otherwise."""

    def __init__(self, seed: int, color, n: int, night: bool):
        rng = np.random.default_rng(seed)
        self.p = rng.random((n, 4))  # x, y phase, size, speed
        self.color, self.night = color, night

    def draw(self, im: Image.Image, t: float) -> None:
        d = ImageDraw.Draw(im)
        for x, y0, s, v in self.p:
            y = (y0 * K.H + t * (30 + 50 * v)) % K.H
            xx = x * K.W + 18 * math.sin(t * (0.6 + v) + y0 * 9)
            r = 3 + 6 * s
            a = int(90 + 120 * (0.5 + 0.5 * math.sin(t * 2 + x * 20))) if self.night else 150
            d.ellipse((xx - r, y - r, xx + r, y + r), fill=self.color + (a,))


def frames(loop: dict, seed: int, total: float):
    night = loop["look"] == "night"
    base = B3.night_bg(seed) if night else K.background(seed)
    f = K.font(76)
    layers, y = [], 330
    for beat in loop["beats"]:
        layer = Image.new("RGBA", (K.W, K.H), (0, 0, 0, 0))
        lines = K.balanced(ImageDraw.Draw(layer), beat, f, 820)
        y = K.text_boxes(layer, lines, f, y + len(lines) * (f.size + 24) // 2) + 36
        layers.append(layer)
    floor = K.SAFE[3] - 20
    style, day = loop["tree"]
    tree = B.fit(style, day, 800, min(780, floor - y - 90))
    # Pad so rotation about the base never clips.
    pad = Image.new("RGBA", (tree.width + 200, tree.height * 2), (0, 0, 0, 0))
    pad.alpha_composite(tree, (100, 0))
    pivot = (pad.width // 2, tree.height)
    color = PARTICLES.get(style, (255, 236, 190) if night else (255, 250, 236))
    parts = Particles(seed, color, 26 if style in PARTICLES else 40, night)
    starts = [0.2] if len(layers) == 1 else [0.2, 2.4]
    halo = None
    if night:
        halo = Image.new("RGBA", (K.W, K.H), (0, 0, 0, 0))
        hb = floor - tree.height // 2
        ImageDraw.Draw(halo).ellipse((K.CX - 460, hb - 460, K.CX + 460, hb + 460), fill=(255, 226, 170, 40))
        from PIL import ImageFilter
        halo = halo.filter(ImageFilter.GaussianBlur(100))
    for k in range(int(total * FPS)):
        t = k / FPS
        im = base.copy()
        if halo:
            im.alpha_composite(halo)
        zoom = 1 + 0.05 * t / total
        angle = 1.4 * math.sin(2 * math.pi * t / 4.5)
        tr = pad.rotate(angle, resample=Image.BICUBIC, center=pivot)
        if zoom != 1:
            tr = tr.resize((int(tr.width * zoom), int(tr.height * zoom)), Image.BILINEAR)
        bx, by = K.CX, floor
        im.alpha_composite(tr, (int(bx - pivot[0] * zoom), int(by - pivot[1] * zoom)))
        parts.draw(im, t)
        for layer, s in zip(layers, starts):
            a = min(1.0, max(0.0, (t - s) / 0.3))
            if a >= 1:
                im.alpha_composite(layer)
            elif a > 0:
                l2 = layer.copy()
                l2.putalpha(layer.getchannel("A").point(lambda v, a=a: int(v * a)))
                im.alpha_composite(l2)
        yield im


def render(loop: dict, seed: int) -> None:
    words = sum(len(b.split()) for b in loop["beats"])
    total = max(6.0, min(11.0, 2.6 + words * 0.32))
    OUT.mkdir(parents=True, exist_ok=True)
    V.encode(frames(loop, seed, total), total, total - 1.0, OUT / f"{loop['id']}.mp4")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only")
    args = ap.parse_args()
    only = set(args.only.split(",")) if args.only else None
    for i, loop in enumerate(LOOPS):
        if only and loop["id"] not in only:
            continue
        render(loop, 700 + i)
        print(loop["id"], f"{(OUT / (loop['id'] + '.mp4')).stat().st_size / 1e6:.1f} MB", flush=True)


if __name__ == "__main__":
    main()
