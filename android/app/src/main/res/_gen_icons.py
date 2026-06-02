"""Generate PNG launcher icons for all mipmap densities."""
from PIL import Image, ImageDraw, ImageFont
import os, math

RES = r"C:\Users\am893131\Documents\refundoo\android\app\src\main\res"

# density → icon size in px
DENSITIES = {
    "mipmap-mdpi":    48,
    "mipmap-hdpi":    72,
    "mipmap-xhdpi":   96,
    "mipmap-xxhdpi":  144,
    "mipmap-xxxhdpi": 192,
}

BG_COLOR  = (76, 230, 230)   # #4CE6E6 teal
FG_COLOR  = (17, 23, 23)     # #111717 dark

def draw_icon(size):
    img = Image.new("RGBA", (size, size), BG_COLOR + (255,))
    d   = ImageDraw.Draw(img)

    # Draw a simple "R" letter centred
    font_size = int(size * 0.55)
    try:
        fnt = ImageFont.truetype("arial.ttf", font_size)
    except Exception:
        fnt = ImageFont.load_default()

    text = "R"
    bbox = d.textbbox((0, 0), text, font=fnt)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = (size - tw) / 2 - bbox[0]
    y = (size - th) / 2 - bbox[1]
    d.text((x, y), text, fill=FG_COLOR + (255,), font=fnt)
    return img

for folder, px in DENSITIES.items():
    out_dir = os.path.join(RES, folder)
    os.makedirs(out_dir, exist_ok=True)
    img = draw_icon(px)
    img.save(os.path.join(out_dir, "ic_launcher.png"))
    img.save(os.path.join(out_dir, "ic_launcher_round.png"))
    print(f"  {folder}/ic_launcher.png  ({px}x{px})")

print("Done.")
