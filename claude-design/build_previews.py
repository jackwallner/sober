from pathlib import Path
from PIL import Image

ROOT = Path('/Users/jackwallner/sober')
RAW = ROOT / 'claude-design/screenshots'
OUT = ROOT / 'fastlane/screenshots/en-US'
FRAMES = ROOT / 'claude-design/generated_frames'
OUT.mkdir(parents=True, exist_ok=True)

W, H = 1290, 2796
specs = [
    ('01_grow', 'frame_01_grow.png', 'raw_01_today.png'),
    ('02_counted', 'frame_02_counted.png', 'raw_02_timeline.png'),
    ('03_recover', 'frame_03_recover.png', 'raw_03_health.png'),
    ('04_pocket', 'frame_04_pocket.png', 'raw_06_paywall.png'),
    ('05_reflect', 'frame_05_reflect.png', 'raw_04_journal.png'),
    ('06_milestones', 'frame_06_milestones.png', 'raw_05_stats.png'),
]

def replace_placeholder(frame: Image.Image, raw_name: str) -> Image.Image:
    pixels = frame.load()
    magenta = []
    for y in range(H):
        for x in range(W):
            r, g, b, _ = pixels[x, y]
            if r > 205 and g < 80 and b > 150:
                magenta.append((x, y))
    if not magenta:
        raise ValueError(f'No magenta placeholder found in {raw_name}')
    left = min(x for x, _ in magenta)
    top = min(y for _, y in magenta)
    right = max(x for x, _ in magenta)
    bottom = max(y for _, y in magenta)
    raw = Image.open(RAW/raw_name).convert('RGBA').resize((right-left+1, bottom-top+1), Image.Resampling.LANCZOS)
    mask = Image.new('L', (W, H), 0)
    mask_pixels = mask.load()
    for x, y in magenta:
        mask_pixels[x, y] = 255
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    layer.alpha_composite(raw, (left, top))
    frame.paste(layer, (0, 0), mask)
    return frame

for slug, frame, raw in specs:
    c = Image.open(FRAMES/frame).convert('RGBA').resize((W, H), Image.Resampling.LANCZOS)
    c = replace_placeholder(c, raw)
    c.convert('RGB').save(OUT/f'appstore_preview_{slug}.png', 'PNG', optimize=True)

thumbs = []
for slug, *_ in specs:
    im = Image.open(OUT/f'appstore_preview_{slug}.png').resize((322,699), Image.Resampling.LANCZOS)
    thumbs.append(im)
sheet = Image.new('RGB', (322*3, 699*2), '#FFFDF9')
for i, im in enumerate(thumbs):
    sheet.paste(im, ((i%3)*322, (i//3)*699))
sheet.save(OUT/'appstore_preview_contact_sheet.png', 'PNG', optimize=True)
