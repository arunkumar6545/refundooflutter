"""Generate polished PNG launcher icons for all mipmap densities.
Draws a teal gradient background with a stylised receipt + return-arrow icon.
"""
from PIL import Image, ImageDraw
import math, os

RES = r"C:\Users\am893131\Documents\refundoo\android\app\src\main\res"

DENSITIES = {
    "mipmap-mdpi":    48,
    "mipmap-hdpi":    72,
    "mipmap-xhdpi":   96,
    "mipmap-xxhdpi":  144,
    "mipmap-xxxhdpi": 192,
}

# Brand colours
TEAL_TOP    = (22, 196, 196)   # #16C4C4
TEAL_BOTTOM = (10, 120, 140)   # #0A788C
WHITE       = (255, 255, 255)
WHITE_DIM   = (220, 245, 245)


def lerp_color(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))


def draw_gradient_bg(draw, size):
    for y in range(size):
        t = y / size
        r, g, b = lerp_color(TEAL_TOP, TEAL_BOTTOM, t)
        draw.line([(0, y), (size, y)], fill=(r, g, b, 255))


def draw_rounded_rect(draw, x0, y0, x1, y1, radius, fill):
    draw.rectangle([x0 + radius, y0, x1 - radius, y1], fill=fill)
    draw.rectangle([x0, y0 + radius, x1, y1 - radius], fill=fill)
    draw.ellipse([x0, y0, x0 + radius * 2, y0 + radius * 2], fill=fill)
    draw.ellipse([x1 - radius * 2, y0, x1, y0 + radius * 2], fill=fill)
    draw.ellipse([x0, y1 - radius * 2, x0 + radius * 2, y1], fill=fill)
    draw.ellipse([x1 - radius * 2, y1 - radius * 2, x1, y1], fill=fill)


def draw_icon(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Background with rounded corners (for adaptive icons the bg is full square,
    # but let's make it look great as a standard icon too)
    pad = int(size * 0.04)
    r_bg = int(size * 0.22)
    draw_gradient_bg(draw, size)

    # ── Receipt shape ────────────────────────────────────────────────────
    # White receipt card, slightly raised
    rx = int(size * 0.22)
    ry = int(size * 0.18)
    rw = int(size * 0.56)
    rh = int(size * 0.52)
    rr = int(size * 0.08)
    shadow_offset = max(2, int(size * 0.025))
    # Drop shadow
    draw_rounded_rect(draw, rx + shadow_offset, ry + shadow_offset,
                      rx + rw + shadow_offset, ry + rh + shadow_offset,
                      rr, (0, 60, 80, 80))
    # Card face
    draw_rounded_rect(draw, rx, ry, rx + rw, ry + rh, rr, WHITE + (255,))

    # Zigzag bottom edge of receipt (3 teeth)
    teeth = 5
    tooth_w = rw // teeth
    tooth_h = int(size * 0.04)
    by = ry + rh
    pts = [(rx, by)]
    for i in range(teeth):
        pts.append((rx + tooth_w * i + tooth_w // 2, by - tooth_h))
        pts.append((rx + tooth_w * (i + 1), by))
    pts.append((rx, by))
    # Erase bottom of card so zigzag appears
    draw.rectangle([rx, by - tooth_h, rx + rw, by + tooth_h + 2], fill=(0, 0, 0, 0))
    # Redraw the card body without bottom part
    draw_rounded_rect(draw, rx, ry, rx + rw, ry + rh - rr, 0, WHITE + (255,))
    draw.rectangle([rx, ry, rx + rw, ry + rh - tooth_h], fill=WHITE + (255,))
    # Draw zigzag teeth in white
    draw.polygon(pts, fill=WHITE + (255,))

    # ── Lines on receipt ────────────────────────────────────────────────
    line_color = (180, 220, 220, 200)
    lx = rx + int(rw * 0.15)
    lw = int(rw * 0.70)
    lh = max(2, int(size * 0.025))
    gap = int(rh * 0.14)
    for i in range(3):
        ly = ry + int(rh * 0.20) + gap * i
        w_frac = [1.0, 0.7, 0.5][i]
        draw.rectangle([lx, ly, lx + int(lw * w_frac), ly + lh], fill=line_color)

    # ── Return-arrow badge ───────────────────────────────────────────────
    # Teal circle badge in bottom-right
    bx = rx + rw - int(size * 0.03)
    by2 = ry + rh - int(size * 0.03)
    br = int(size * 0.18)
    draw.ellipse([bx - br, by2 - br, bx + br, by2 + br],
                 fill=TEAL_BOTTOM + (255,))
    # Arrow: a curved "↩" drawn as thick arc + arrowhead
    ac = (bx, by2)
    ar = int(br * 0.55)
    lw2 = max(2, int(size * 0.04))
    # Arc (approx with polyline)
    arc_pts = []
    for deg in range(20, 310, 10):
        rad = math.radians(deg)
        arc_pts.append((ac[0] + ar * math.cos(rad), ac[1] + ar * math.sin(rad)))
    for i in range(len(arc_pts) - 1):
        draw.line([arc_pts[i], arc_pts[i + 1]], fill=WHITE + (255,), width=lw2)
    # Arrowhead at the start of arc (deg=20)
    tip = arc_pts[0]
    ah = int(ar * 0.45)
    draw.polygon([
        (tip[0], tip[1] - ah // 2),
        (tip[0] + ah, tip[1]),
        (tip[0], tip[1] + ah // 2),
    ], fill=WHITE + (255,))

    return img


for folder, px in DENSITIES.items():
    out_dir = os.path.join(RES, folder)
    os.makedirs(out_dir, exist_ok=True)
    img = draw_icon(px)
    img.save(os.path.join(out_dir, "ic_launcher.png"))
    img.save(os.path.join(out_dir, "ic_launcher_round.png"))
    print(f"  {folder}/ic_launcher.png  ({px}x{px})")

print("Done.")
