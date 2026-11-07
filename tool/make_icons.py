"""Draws the launcher icon: the yellow word "وين" on enamel blue, like the shop sign.

Run from WAIN/mobile:  python3 tool/make_icons.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ENAMEL, DEEP, TAG = "#123c8c", "#0c2a66", "#f6c428"
RES = Path("android/app/src/main/res")
FONT = "assets/fonts/Lalezar-Regular.ttf"
SIZES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}


def draw(size: int = 1024) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(image)
    d.rounded_rectangle((0, 0, size - 1, size - 1), radius=size * 0.22, fill=ENAMEL)
    band = size * 0.075  # the yellow rule under the sign
    d.rectangle((0, size - band * 2.2, size, size - band * 1.2), fill=TAG)
    font = ImageFont.truetype(FONT, int(size * 0.5), layout_engine=ImageFont.Layout.RAQM)
    text = "وين"
    box = d.textbbox((0, 0), text, font=font, direction="rtl", language="ar")
    x = (size - (box[2] - box[0])) / 2 - box[0]
    y = (size * 0.86 - (box[3] - box[1])) / 2 - box[1]
    d.text((x, y + size * 0.03), text, font=font, fill=DEEP, direction="rtl", language="ar")
    d.text((x, y), text, font=font, fill=TAG, direction="rtl", language="ar")
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size - 1, size - 1), radius=size * 0.22, fill=255)
    image.putalpha(mask)
    return image


def foreground(size: int = 1080) -> Image.Image:
    """Adaptive-icon layer: 108dp canvas, art kept inside the middle 66dp."""
    art = draw(int(size * 66 / 108))
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    offset = (size - art.width) // 2
    layer.alpha_composite(art, (offset, offset))
    return layer


if __name__ == "__main__":
    big = draw()
    for folder, px in SIZES.items():
        big.resize((px, px), Image.LANCZOS).save(RES / f"mipmap-{folder}" / "ic_launcher.png")
    big.resize((512, 512), Image.LANCZOS).save("tool/icon-512.png")
    layer = foreground()
    for folder, px in SIZES.items():
        layer.resize((px * 108 // 48,) * 2, Image.LANCZOS).save(RES / f"mipmap-{folder}" / "ic_launcher_foreground.png")
    adaptive = RES / "mipmap-anydpi-v26"
    adaptive.mkdir(exist_ok=True)
    (adaptive / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/wain_enamel"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n',
        encoding="utf-8",
    )
    print("icons written")
