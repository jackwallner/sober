from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path("/Users/jackwallner/sober")
RAW = ROOT / "claude-design/screenshots"
OUT = ROOT / "fastlane/screenshots/en-US"
OUT.mkdir(parents=True, exist_ok=True)

W, H = 1290, 2796
SERIF = "/System/Library/Fonts/NewYork.ttf"
SANS = "/System/Library/Fonts/SFNS.ttf"
CREAM = "#F6F0E2"
GREEN = "#173F31"
MOSS = "#285F48"
GOLD = "#CFA54C"
INK = "#11120F"

SPECS = [
    ("01_counter", "Your sober days,\nat a glance.", "Counter, check-in, and calendar without the noise.", "raw_01_today.png", "light"),
    ("02_garden", "A garden that\ngrows with you.", "Every alcohol-free day changes your bonsai.", "raw_01_today.png", "dark"),
    ("03_savings", "See what drinking\nused to cost.", "Track the money and calories you keep.", "raw_05_stats.png", "light"),
    ("04_recovery", "Know what recovery\nis changing.", "Evidence-linked milestones, day by day.", "raw_03_health.png", "dark"),
    ("05_private", "Private. No account.\nYour data stays yours.", "A journal and daily check-ins only you can see.", "raw_04_journal.png", "light"),
    ("06_trial", "Try every Bloom+ tool\nfree for 7 days.", "Yearly or monthly. Pay nothing today.", "raw_06_paywall.png", "dark"),
]


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size)


def fit_image(image: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    left, top, right, bottom = box
    width, height = right - left, bottom - top
    source_ratio = image.width / image.height
    target_ratio = width / height
    if source_ratio > target_ratio:
        crop_width = int(image.height * target_ratio)
        x = (image.width - crop_width) // 2
        image = image.crop((x, 0, x + crop_width, image.height))
    else:
        crop_height = int(image.width / target_ratio)
        y = max(0, (image.height - crop_height) // 3)
        image = image.crop((0, y, image.width, y + crop_height))
    return image.resize((width, height), Image.Resampling.LANCZOS)


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius, fill=255)
    return mask


def add_phone(canvas: Image.Image, raw_name: str, box: tuple[int, int, int, int]) -> None:
    left, top, right, bottom = box
    width, height = right - left, bottom - top
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((left - 18, top + 22, right + 18, bottom + 52), 84, fill=(0, 0, 0, 115))
    shadow = shadow.filter(ImageFilter.GaussianBlur(34))
    canvas.alpha_composite(shadow)

    frame = Image.new("RGBA", (width + 34, height + 34), (18, 18, 18, 255))
    ImageDraw.Draw(frame).rounded_rectangle((0, 0, width + 33, height + 33), 78, fill=(17, 17, 17), outline=(75, 75, 75), width=5)
    screen = fit_image(Image.open(RAW / raw_name).convert("RGBA"), (0, 0, width, height))
    frame.paste(screen, (17, 17), rounded_mask((width, height), 62))
    canvas.alpha_composite(frame, (left - 17, top - 17))


def draw_wrapped(draw: ImageDraw.ImageDraw, text: str, position: tuple[int, int], fnt: ImageFont.FreeTypeFont, fill: str, spacing: int) -> int:
    x, y = position
    for line in text.split("\n"):
        draw.text((x, y), line, font=fnt, fill=fill)
        y += int(fnt.size * 1.02) + spacing
    return y


def decorate(draw: ImageDraw.ImageDraw, theme: str) -> None:
    color = GOLD if theme == "dark" else MOSS
    for x, y, r in [(70, 130, 18), (1140, 190, 11), (1090, 2480, 17), (120, 2580, 10)]:
        draw.ellipse((x - r, y - r, x + r, y + r), outline=color, width=4)
    draw.arc((-130, 2100, 500, 2730), 210, 340, fill=color, width=5)
    draw.arc((890, -240, 1450, 350), 30, 160, fill=color, width=5)


def make_frame(slug: str, headline: str, subhead: str, raw_name: str, theme: str) -> None:
    bg = GREEN if theme == "dark" else CREAM
    primary = "#FFFFFF" if theme == "dark" else INK
    secondary = "#EDE4CF" if theme == "dark" else "#51534C"
    accent = GOLD if theme == "dark" else MOSS
    canvas = Image.new("RGBA", (W, H), bg)
    draw = ImageDraw.Draw(canvas)
    decorate(draw, theme)

    draw.text((92, 100), "SOBER", font=font(SANS, 27), fill=accent, stroke_width=0)
    draw.text((92, 143), "PRIVATE SOBRIETY TRACKER", font=font(SANS, 20), fill=secondary)

    headline_font = font(SERIF, 110 if len(headline) < 36 else 94)
    y = draw_wrapped(draw, headline, (90, 245), headline_font, primary, 2)
    draw.text((94, y + 28), subhead, font=font(SANS, 37), fill=secondary)

    phone_top = 900
    phone_bottom = 2615
    add_phone(canvas, raw_name, (238, phone_top, 1052, phone_bottom))

    if slug == "06_trial":
        badge = (355, 760, 935, 845)
        draw.rounded_rectangle(badge, 42, fill=GOLD)
        draw.text((425, 780), "$0 TODAY  •  7 DAYS", font=font(SANS, 30), fill=GREEN)
    elif slug == "05_private":
        badge = (385, 765, 905, 845)
        draw.rounded_rectangle(badge, 40, fill=MOSS)
        draw.text((447, 785), "NO LOGIN REQUIRED", font=font(SANS, 27), fill="#FFFFFF")

    canvas.convert("RGB").save(OUT / f"appstore_preview_{slug}.png", "PNG", optimize=True)


for spec in SPECS:
    make_frame(*spec)

for old in OUT.glob("appstore_preview_*.png"):
    if not any(old.name == f"appstore_preview_{spec[0]}.png" for spec in SPECS):
        old.unlink()

thumbs = [Image.open(OUT / f"appstore_preview_{spec[0]}.png").resize((322, 699), Image.Resampling.LANCZOS) for spec in SPECS]
sheet = Image.new("RGB", (966, 1398), CREAM)
for index, image in enumerate(thumbs):
    sheet.paste(image, ((index % 3) * 322, (index // 3) * 699))
sheet.save(ROOT / "claude-design/appstore_preview_contact_sheet.png", "PNG", optimize=True)
