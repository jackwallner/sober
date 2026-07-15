from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path('/Users/jackwallner/sober')
RAW = ROOT / 'claude-design/screenshots'
OUT = ROOT / 'fastlane/screenshots/en-US'
FRAMES = ROOT / 'claude-design/generated_frames'
OUT.mkdir(parents=True, exist_ok=True)

W, H = 1290, 2796
cream = '#F6EFE0'
warm = '#FFFDF9'
moss = '#2F5B45'
ink = '#1A1A18'
ink_dark = '#FFFFFF'
sand = '#C49C6C'

font_candidates = [
    '/System/Library/Fonts/SFNSRounded-Bold.otf',
    '/System/Library/Fonts/SFNS.ttf',
    '/Library/Fonts/Arial Bold.ttf',
]
font_path = next((p for p in font_candidates if Path(p).exists()), '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf')
font_sub_path = '/System/Library/Fonts/SFNS.ttf' if Path('/System/Library/Fonts/SFNS.ttf').exists() else font_path

specs = [
    ('01_grow', 'frame_01_grow.png', 'raw_01_today.png', True, cream, ['128 days.', 'Watch it grow.'], 'Every alcohol-free day grows your bonsai.', 'grow.'),
    ('02_counted', 'frame_02_counted.png', 'raw_02_timeline.png', False, moss, ['Every dry day,', 'counted.'], 'Your streak and calendar at a glance.', 'counted.'),
    ('03_recover', 'frame_03_recover.png', 'raw_03_health.png', True, warm, ['See your body', 'come back.'], 'Recovery milestones, day by day.', 'come back.'),
    ('04_pocket', 'frame_04_pocket.png', 'raw_06_paywall.png', False, moss, ['$2,560 back', 'in your pocket.'], 'See what sobriety saves - money and calories.', '$2,560'),
    ('05_reflect', 'frame_05_reflect.png', 'raw_04_journal.png', True, cream, ['A private place', 'to reflect.'], 'Daily prompts and a journal only you can see.', 'private'),
    ('06_milestones', 'frame_06_milestones.png', 'raw_05_stats.png', False, warm, ['Milestones', 'worth keeping.'], "Achievements, savings, and what's next.", 'keeping.'),
]

def fit_font(size: int):
    return ImageFont.truetype(font_path, size)

def add_copy(canvas, top: bool, field: str, lines: list[str], sub: str, emphasis: str):
    band_h = 640
    y0 = 0 if top else H-band_h
    draw = ImageDraw.Draw(canvas)
    if field == moss:
        color = ink_dark
        sub_color = '#E8EFE9'
        accent = sand
    else:
        color = ink
        sub_color = '#5C5B54'
        accent = moss
    f = fit_font(86)
    y = y0 + 92
    for line in lines:
        if emphasis in line:
            prefix, suffix = line.split(emphasis, 1)
            draw.text((76, y), prefix, font=f, fill=color)
            prefix_width = draw.textlength(prefix, font=f)
            draw.text((76 + prefix_width, y), emphasis, font=f, fill=accent)
            emphasis_width = draw.textlength(emphasis, font=f)
            draw.text((76 + prefix_width + emphasis_width, y), suffix, font=f, fill=color)
        else:
            draw.text((76, y), line, font=f, fill=color)
        y += 104
    sf = ImageFont.truetype(font_sub_path, 34)
    draw.text((78, y+16), sub, font=sf, fill=sub_color)

def add_device(canvas, raw_name: str, top: bool):
    raw = Image.open(RAW/raw_name).convert('RGB')
    device_w = 900
    device_h = round(raw.height * device_w / raw.width)
    raw = raw.resize((device_w, device_h), Image.Resampling.LANCZOS)
    x = (W-device_w)//2
    y = 700 if top else 90
    shell = Image.new('RGBA', (device_w+28, device_h+28), (0,0,0,0))
    sd = ImageDraw.Draw(shell)
    sd.rounded_rectangle((14,14,device_w+14,device_h+14), radius=92, fill='#111210', outline='#272824', width=4)
    shadow = Image.new('RGBA', canvas.size, (0,0,0,0))
    sh = Image.new('RGBA', shell.size, (0,0,0,0)); sh.paste(shell, (x,y), shell)
    shadow.alpha_composite(sh)
    shadow = shadow.filter(ImageFilter.GaussianBlur(12))
    canvas.alpha_composite(shadow)
    mask = Image.new('L', raw.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0,0,device_w,device_h), radius=78, fill=255)
    canvas.paste(raw, (x+14,y+14), mask)

for slug, frame, raw, top, field, lines, sub, emphasis in specs:
    c = Image.open(FRAMES/frame).convert('RGBA').resize((W, H), Image.Resampling.LANCZOS)
    add_copy(c, top, field, lines, sub, emphasis)
    add_device(c, raw, top)
    c.convert('RGB').save(OUT/f'appstore_preview_{slug}.png', 'PNG', optimize=True)

thumbs = []
for slug, *_ in specs:
    im = Image.open(OUT/f'appstore_preview_{slug}.png').resize((322,699), Image.Resampling.LANCZOS)
    thumbs.append(im)
sheet = Image.new('RGB', (322*3, 699*2), warm)
for i, im in enumerate(thumbs):
    sheet.paste(im, ((i%3)*322, (i//3)*699))
sheet.save(OUT/'appstore_preview_contact_sheet.png', 'PNG', optimize=True)
