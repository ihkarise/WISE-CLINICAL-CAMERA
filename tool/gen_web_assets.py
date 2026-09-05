#!/usr/bin/env python3
"""Generate the WISE Clinical Camera *website* raster assets.

The brand mark is identical to the app launcher icon (see tool/gen_icons.py and
lib/shared/widgets/wise_logo.dart): a white camera aperture over a Deep Navy ->
Wise Blue gradient with a single Wise Red focus point. This script is the web
counterpart of gen_icons.py and reuses the same geometry so the website and the
application share one visual identity (single source of truth).

Outputs (all under website/):
  assets/brand/apple-touch-icon.png     180x180  iOS home-screen icon
  assets/brand/favicon-32.png            32x32   legacy favicon fallback
  assets/brand/favicon-16.png            16x16   legacy favicon fallback
  assets/icons/icon-192.png             192x192  PWA / Android
  assets/icons/icon-512.png             512x512  PWA / Android
  assets/icons/icon-maskable-512.png    512x512  PWA maskable (full-bleed)
  assets/social/og-image.png           1200x630  Open Graph / social card

Run:  python3 tool/gen_web_assets.py
Requires: Pillow.  SVG masters (favicon.svg) are authored by hand and are the
scalable source; these PNGs exist only for surfaces that cannot use SVG.
"""
import math
import os

from PIL import Image, ImageDraw, ImageFont

WEB = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "website"))

DEEP_NAVY = (16, 24, 40)      # #101828
WISE_BLUE = (36, 62, 143)     # #243E8F
WISE_RED = (214, 31, 75)      # #D61F4B
SLATE = (148, 163, 184)       # muted text on dark
WHITE = (255, 255, 255)

SS = 4  # supersample factor


def gradient(size_w, size_h, top=DEEP_NAVY, bottom=WISE_BLUE):
    img = Image.new("RGBA", (size_w, size_h), (0, 0, 0, 0))
    px = img.load()
    for y in range(size_h):
        t = y / max(1, size_h - 1)
        r = round(top[0] + (bottom[0] - top[0]) * t)
        g = round(top[1] + (bottom[1] - top[1]) * t)
        b = round(top[2] + (bottom[2] - top[2]) * t)
        for x in range(size_w):
            px[x, y] = (r, g, b, 255)
    return img


def rounded(img, radius_ratio):
    size = img.size[0]
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, img.size[0] - 1, img.size[1] - 1],
        radius=int(size * radius_ratio), fill=255)
    img.putalpha(mask)
    return img


def aperture_mark(size, radius_frac):
    """A white camera aperture on a transparent canvas (blades + iris cut out)."""
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = cy = S / 2
    R = S * radius_frac

    d.ellipse([cx - R, cy - R, cx + R, cy + R], fill=WHITE)

    inner = R * 0.52
    hexagon = [
        (cx + inner * math.cos(math.radians(60 * k - 90)),
         cy + inner * math.sin(math.radians(60 * k - 90)))
        for k in range(6)
    ]
    d.polygon(hexagon, fill=(0, 0, 0, 0))

    blade_w = int(R * 0.11)
    for k in range(6):
        vx, vy = hexagon[k]
        a_out = math.radians(60 * k - 90 + 34)
        ox = cx + (R * 1.02) * math.cos(a_out)
        oy = cy + (R * 1.02) * math.sin(a_out)
        d.line([(vx, vy), (ox, oy)], fill=(0, 0, 0, 0), width=blade_w)

    dot = R * 0.14
    d.ellipse([cx - dot, cy - dot, cx + dot, cy + dot], fill=WISE_RED + (255,))

    return img.resize((size, size), Image.LANCZOS)


def icon(size, radius_ratio=0.22, mark_frac=0.30):
    bg = gradient(size, size)
    if radius_ratio > 0:
        bg = rounded(bg, radius_ratio)
    mark = aperture_mark(size, radius_frac=mark_frac)
    bg.alpha_composite(mark)
    return bg


def ensure(path):
    os.makedirs(path, exist_ok=True)


def _font(size):
    for path in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def og_image():
    W, H = 1200, 630
    img = gradient(W, H)
    d = ImageDraw.Draw(img)

    # Mark on the left.
    mark = aperture_mark(300, radius_frac=0.5)
    boxed = gradient(300, 300)
    boxed = rounded(boxed, 0.22)
    boxed.alpha_composite(mark)
    img.alpha_composite(boxed, (90, 165))

    x = 450
    d.text((x, 214), "WISE Clinical Camera", font=_font(54), fill=WHITE)
    d.text((x, 300), "Take the same photograph again.", font=_font(32),
           fill=(226, 232, 240))
    d.text((x, 372), "Standardized clinical photography for", font=_font(28),
           fill=SLATE)
    d.text((x, 410), "reproducible before & after documentation.",
           font=_font(28), fill=SLATE)
    # Restrained brand line with the Wise Red accent.
    d.rectangle([x, 470, x + 46, 476], fill=WISE_RED)
    d.text((x + 62, 458), "WiseAiTechs  ·  For All Medicos", font=_font(26),
           fill=(226, 232, 240))
    return img.convert("RGB")


def main():
    ensure(os.path.join(WEB, "assets", "brand"))
    ensure(os.path.join(WEB, "assets", "icons"))
    ensure(os.path.join(WEB, "assets", "social"))

    icon(180).save(os.path.join(WEB, "assets", "brand", "apple-touch-icon.png"))
    icon(32).save(os.path.join(WEB, "assets", "brand", "favicon-32.png"))
    icon(16).save(os.path.join(WEB, "assets", "brand", "favicon-16.png"))
    icon(192).save(os.path.join(WEB, "assets", "icons", "icon-192.png"))
    icon(512).save(os.path.join(WEB, "assets", "icons", "icon-512.png"))

    # Maskable: full-bleed gradient (no rounding) with the mark inside the
    # 66% adaptive safe zone.
    maskable = gradient(512, 512)
    maskable.alpha_composite(aperture_mark(512, radius_frac=0.24))
    maskable.save(os.path.join(WEB, "assets", "icons", "icon-maskable-512.png"))

    og_image().save(os.path.join(WEB, "assets", "social", "og-image.png"),
                    optimize=True)

    print("web assets generated")


if __name__ == "__main__":
    main()
