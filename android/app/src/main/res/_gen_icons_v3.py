"""Refundoo launcher icon generator – v3 premium design.

Design language:
  • Deep navy → dark-teal diagonal gradient background
  • White receipt card with rounded corners, drop shadow
  • Teal (#4CE6E6) header strip on card
  • Horizontal bars simulating line items
  • Circular return-arrow badge (teal) overlapping bottom-right of card
  • White arrowhead drawn with a polygon

Run with: python _gen_icons_v3.py
Requires: pip install Pillow
"""
from PIL import Image, ImageDraw
import os
import math

RES        = r"C:\Users\am893131\Documents\refundoo\android\app\src\main\res"
ASSET_OUT  = r"C:\Users\am893131\Documents\refundoo\assets\images"

DENSITIES = {
    "mipmap-mdpi":    48,
    "mipmap-hdpi":    72,
    "mipmap-xhdpi":   96,
    "mipmap-xxhdpi":  144,
    "mipmap-xxxhdpi": 192,
}

# Palette  (R, G, B)
NAVY    = (10,  22,  45)    # #0A162D deep navy background
TEAL_D  = (10, 108, 128)    # #0A6C80 dark teal background
TEAL    = (76, 230, 230)    # #4CE6E6 app primary
WHITE   = (255, 255, 255)
RECEIPT = (245, 250, 255)   # card body
LINE_C  = (185, 210, 220)   # line-item bars


def lerp_rgb(a, b, t):
    return tuple(max(0, min(255, int(a[i] + (b[i] - a[i]) * t))) for i in range(3))


def draw_icon(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size))
    px = img.load()
    s = float(size)

    # ── Diagonal gradient background ──────────────────────────────
    for y in range(size):
        for x in range(size):
            t = (x * 0.3 + y * 0.7) / size
            c = lerp_rgb(NAVY, TEAL_D, t)
            px[x, y] = c + (255,)

    d = ImageDraw.Draw(img, "RGBA")

    # ── Receipt card ──────────────────────────────────────────────
    rw = s * 0.52
    rh = rw * 1.32
    rx = (s - rw) / 2 - s * 0.03   # nudge left so badge fits right
    ry = (s - rh) / 2 - s * 0.04   # nudge up
    rc = max(3, int(s * 0.075))

    # Drop shadow
    d.rounded_rectangle(
        [rx + s*0.03, ry + s*0.03, rx + rw + s*0.03, ry + rh + s*0.03],
        radius=rc, fill=(0, 0, 0, 75),
    )

    # Card body
    d.rounded_rectangle(
        [rx, ry, rx + rw, ry + rh],
        radius=rc, fill=RECEIPT + (255,),
    )

    # Teal header strip
    header_h = rh * 0.26
    d.rounded_rectangle(
        [rx, ry, rx + rw, ry + header_h],
        radius=rc, fill=TEAL + (255,),
    )
    # Flatten bottom corners of header
    d.rectangle(
        [rx, ry + header_h * 0.55, rx + rw, ry + header_h],
        fill=TEAL + (255,),
    )

    # White title bars on header
    bw  = rw * 0.46
    bx  = rx + (rw - bw) / 2
    bh  = max(2, s * 0.026)
    by  = ry + header_h * 0.24
    d.rounded_rectangle([bx, by, bx + bw, by + bh], radius=1, fill=(255, 255, 255, 235))
    d.rounded_rectangle(
        [bx + bw*0.12, by + bh*1.7, bx + bw*0.88, by + bh*2.5],
        radius=1, fill=(255, 255, 255, 130),
    )

    # ── Line items ────────────────────────────────────────────────
    lx0      = rx + rw * 0.14
    lx_max   = rx + rw * 0.86
    item_h   = max(2, s * 0.023)
    row_y0   = ry + rh * 0.34
    spacing  = rh * 0.114

    widths = [0.88, 0.65, 0.74, 0.50]
    for i, w in enumerate(widths):
        ly  = row_y0 + i * spacing
        end = lx0 + (lx_max - lx0) * w
        d.rounded_rectangle([lx0, ly, end, ly + item_h], radius=1, fill=LINE_C + (255,))
        # small amount-dot on right
        dot_x = rx + rw * 0.79
        dot_w = max(3, s * 0.032)
        d.rounded_rectangle(
            [dot_x, ly, dot_x + dot_w, ly + item_h],
            radius=1, fill=(150, 195, 210, 200),
        )

    # Separator + total row
    sep_y = row_y0 + len(widths) * spacing + item_h * 0.7
    d.rectangle([lx0, sep_y, lx_max, sep_y + max(1, int(s * 0.006))],
                fill=(195, 220, 228, 160))
    tot_y = sep_y + max(2, s * 0.02)
    d.rounded_rectangle(
        [lx0, tot_y, lx0 + (lx_max - lx0) * 0.93, tot_y + item_h * 1.1],
        radius=1, fill=TEAL + (90,),
    )

    # ── Return-arrow badge ────────────────────────────────────────
    bcx = rx + rw + s * 0.008   # center x (overlapping card right edge)
    bcy = ry + rh - s * 0.02    # center y (overlapping card bottom edge)
    br  = s * 0.21              # radius

    # Soft outer glow
    for g in range(5, 0, -1):
        d.ellipse(
            [bcx-br-g*2, bcy-br-g*2, bcx+br+g*2, bcy+br+g*2],
            fill=(76, 230, 230, 18 * g),
        )

    # Badge background: dark ring + bright fill
    d.ellipse([bcx-br, bcy-br, bcx+br, bcy+br], fill=(10, 140, 155, 255))
    d.ellipse([bcx-br+2, bcy-br+2, bcx+br-2, bcy+br-2], fill=TEAL + (255,))

    # White border
    bord = max(1, int(s * 0.02))
    d.ellipse([bcx-br, bcy-br, bcx+br, bcy+br],
              outline=WHITE + (210,), width=bord)

    # Circular arc (return arrow body)
    ar    = br * 0.56
    arc_w = max(2, int(br * 0.24))
    d.arc(
        [bcx-ar, bcy-ar, bcx+ar, bcy+ar],
        start=55, end=330,
        fill=WHITE + (255,),
        width=arc_w,
    )

    # Arrowhead triangle at arc end (330°)
    ang  = math.radians(330)
    tip  = (bcx + ar * math.cos(ang), bcy + ar * math.sin(ang))
    tang = ang + math.pi / 2   # clockwise tangent
    ah   = br * 0.40
    pts  = [
        tip,
        (tip[0] - ah * math.cos(tang - 0.52), tip[1] - ah * math.sin(tang - 0.52)),
        (tip[0] - ah * math.cos(tang + 0.52), tip[1] - ah * math.sin(tang + 0.52)),
    ]
    d.polygon([(int(p[0]), int(p[1])) for p in pts], fill=WHITE + (255,))

    return img


def make_round(icon: Image.Image) -> Image.Image:
    """Crop the icon to a circle on a transparent background."""
    size = icon.size[0]
    out  = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mask = Image.new("L",    (size, size), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, size-1, size-1], fill=255)
    out.paste(icon, mask=mask)
    return out


# ── Generate mipmap icons ─────────────────────────────────────────
for folder, px in DENSITIES.items():
    out_dir = os.path.join(RES, folder)
    os.makedirs(out_dir, exist_ok=True)
    icon = draw_icon(px)
    icon.save(os.path.join(out_dir, "ic_launcher.png"))
    make_round(icon).save(os.path.join(out_dir, "ic_launcher_round.png"))
    print(f"  {folder}  {px}x{px}  OK")

# ── Generate high-res in-app asset ────────────────────────────────
os.makedirs(ASSET_OUT, exist_ok=True)
hires = draw_icon(512)
hires.save(os.path.join(ASSET_OUT, "app_logo.png"))
print(f"\n  assets/images/app_logo.png  512x512  OK")
print("\nAll icons generated successfully.")
