"""
Generate Refundoo launcher icons for all mipmap densities.

Design:
  • Dark-forest-green → deep-teal diagonal gradient background
  • Bright-teal partial circular arc (~285°) with a return-arrowhead
    (symbolises the refund cycle)
  • Bold white ₹ (rupee) symbol centred inside the arc

Run:  python _gen_icons.py
Requires Pillow:  pip install Pillow
"""

import math, os
from PIL import Image, ImageDraw, ImageFont

# ── paths ──────────────────────────────────────────────────────────────────
RES    = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.normpath(os.path.join(RES, r"..\..\..\..\..\assets\images"))

DENSITIES = {
    "mipmap-mdpi":    48,
    "mipmap-hdpi":    72,
    "mipmap-xhdpi":   96,
    "mipmap-xxhdpi":  144,
    "mipmap-xxxhdpi": 192,
}

APP_LOGO_SIZE = 512   # high-res asset for in-app use

# ── colours ────────────────────────────────────────────────────────────────
BG1   = (10,  53, 48)    # #0A3530 dark forest green
BG2   = (25, 122, 110)   # #197A6E deep teal
RING  = (76, 230, 214)   # #4CE6D6 bright teal
ARROW = (122, 238, 226)  # #7AEEE2 lighter arrowhead
WHITE = (255, 255, 255)
BLACK = (0,   0,   0)

def lerp_color(c1, c2, t):
    return tuple(round(a + (b - a) * t) for a, b in zip(c1, c2))

def draw_icon(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx = cy = size / 2
    r  = size / 2

    # ── gradient background ─────────────────────────────────────────────────
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * size)   # diagonal blend
            c = lerp_color(BG1, BG2, t)
            draw.point((x, y), fill=(*c, 255))

    # ── rounded-corner mask ─────────────────────────────────────────────────
    mask   = Image.new("L", (size, size), 0)
    maskd  = ImageDraw.Draw(mask)
    corner = int(size * 0.22)
    maskd.rounded_rectangle([(0, 0), (size - 1, size - 1)], radius=corner, fill=255)
    img.putalpha(mask)

    draw = ImageDraw.Draw(img)   # redraw after alpha set

    # ── circular return-arc ─────────────────────────────────────────────────
    ring_r  = r * 0.60
    ring_w  = max(2, int(r * 0.10))
    start_a = 48.6   # degrees
    sweep   = 286.0
    end_a   = start_a + sweep

    bbox = [cx - ring_r, cy - ring_r, cx + ring_r, cy + ring_r]
    draw.arc(bbox, start=start_a, end=end_a, fill=RING, width=ring_w)

    # ── arrowhead at end of arc ─────────────────────────────────────────────
    end_rad  = math.radians(end_a)
    ax = cx + ring_r * math.cos(end_rad)
    ay = cy + ring_r * math.sin(end_rad)
    tang     = end_rad + math.pi / 2
    head_len = ring_w * 1.7
    head_w   = ring_w * 0.75

    tip   = (ax + head_len * math.cos(end_rad), ay + head_len * math.sin(end_rad))
    left  = (ax + head_w  * math.cos(tang),     ay + head_w  * math.sin(tang))
    right = (ax - head_w  * math.cos(tang),     ay - head_w  * math.sin(tang))
    draw.polygon([tip, left, right], fill=ARROW)

    # ── ₹ symbol ────────────────────────────────────────────────────────────
    font_size = int(r * 0.82)
    font = None
    for candidate in [
        "arial.ttf",
        "arialuni.ttf",                              # Arial Unicode (has ₹)
        "C:/Windows/Fonts/arial.ttf",
        "C:/Windows/Fonts/seguisym.ttf",             # Segoe UI Symbol
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]:
        try:
            font = ImageFont.truetype(candidate, font_size)
            # Quick check: does this font actually have ₹?
            test = Image.new("RGBA", (10, 10))
            ImageDraw.Draw(test).text((0, 0), "₹", font=font, fill=WHITE)
            break
        except Exception:
            font = None

    if font is None:
        font = ImageFont.load_default()

    symbol = "₹"
    bb  = draw.textbbox((0, 0), symbol, font=font)
    tw  = bb[2] - bb[0]
    th  = bb[3] - bb[1]
    tx  = cx - tw / 2 - bb[0]
    ty  = cy - th / 2 - bb[1] - r * 0.04  # slight upward nudge

    # Subtle shadow
    draw.text((tx + size * 0.015, ty + size * 0.02), symbol,
              fill=(*BLACK, 60), font=font)
    # White symbol
    draw.text((tx, ty), symbol, fill=(*WHITE, 255), font=font)

    return img


def save(img: Image.Image, path: str):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, "PNG")
    print(f"  wrote  {path}  ({img.width}×{img.height})")


if __name__ == "__main__":
    print("Generating launcher icons …")
    for folder, px in DENSITIES.items():
        icon = draw_icon(px)
        base = os.path.join(RES, folder)
        save(icon, os.path.join(base, "ic_launcher.png"))
        save(icon, os.path.join(base, "ic_launcher_round.png"))

    print("\nGenerating high-res in-app logo …")
    logo = draw_icon(APP_LOGO_SIZE)
    save(logo, os.path.join(ASSETS, "app_logo.png"))

    print("\nDone.")
