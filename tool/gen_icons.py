#!/usr/bin/env python3
"""Generate WISE Clinical Camera launcher, adaptive and splash assets.

Brand mark: a camera aperture (iris) rendered in white over a Deep Navy ->
Wise Blue gradient, with a single Wise Red focus point at the centre. The
aperture reads as "camera"; the restrained red dot is the WiseAiTechs accent
used sparingly (UX/UI 2.1). Everything here is drawn from the design tokens in
lib/app/theme/wise_tokens.dart -- no third-party logo is used.
"""
import math
import os

from PIL import Image, ImageDraw

ANDROID_RES = os.path.normpath(
    os.path.join(os.path.dirname(__file__), "..", "android", "app", "src", "main", "res"),
)

DEEP_NAVY = (16, 24, 40)      # #101828
WISE_BLUE = (36, 62, 143)     # #243E8F
WISE_RED = (214, 31, 75)      # #D61F4B
WHITE = (255, 255, 255)

SS = 4  # supersample factor

# Launcher icon sizes (px) per density.
LAUNCHER = {
    "mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192,
}
# Adaptive foreground/background are 108dp base.
ADAPTIVE = {
    "mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432,
}


def gradient_square(size, radius_ratio=0.0):
    """A vertical Deep Navy -> Wise Blue gradient, optionally rounded."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    for y in range(size):
        t = y / max(1, size - 1)
        r = round(DEEP_NAVY[0] + (WISE_BLUE[0] - DEEP_NAVY[0]) * t)
        g = round(DEEP_NAVY[1] + (WISE_BLUE[1] - DEEP_NAVY[1]) * t)
        b = round(DEEP_NAVY[2] + (WISE_BLUE[2] - DEEP_NAVY[2]) * t)
        for x in range(size):
            px[x, y] = (r, g, b, 255)
    if radius_ratio > 0:
        mask = Image.new("L", (size, size), 0)
        md = ImageDraw.Draw(mask)
        rad = int(size * radius_ratio)
        md.rounded_rectangle([0, 0, size - 1, size - 1], radius=rad, fill=255)
        img.putalpha(mask)
    return img


def aperture_mark(size, radius_frac):
    """A white camera aperture on a transparent canvas.

    Returned RGBA image is `size` px. The blade separators and the iris opening
    are transparent so the gradient shows through, on both the legacy icon and
    the adaptive foreground.
    """
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = cy = S / 2
    R = S * radius_frac

    # Solid white lens disc.
    d.ellipse([cx - R, cy - R, cx + R, cy + R], fill=WHITE)

    # Carve the hexagonal iris opening (transparent).
    inner = R * 0.52
    hexagon = [
        (cx + inner * math.cos(math.radians(60 * k - 90)),
         cy + inner * math.sin(math.radians(60 * k - 90)))
        for k in range(6)
    ]
    d.polygon(hexagon, fill=(0, 0, 0, 0))

    # Carve the six blade separators (transparent), each a line from an inner
    # hexagon vertex swept tangentially out to the rim -> the iris "swirl".
    blade_w = int(R * 0.11)
    for k in range(6):
        vx, vy = hexagon[k]
        a_out = math.radians(60 * k - 90 + 34)
        ox = cx + (R * 1.02) * math.cos(a_out)
        oy = cy + (R * 1.02) * math.sin(a_out)
        d.line([(vx, vy), (ox, oy)], fill=(0, 0, 0, 0), width=blade_w)

    # Wise Red focus point at the centre (used sparingly).
    dot = R * 0.14
    d.ellipse([cx - dot, cy - dot, cx + dot, cy + dot], fill=WISE_RED + (255,))

    return img.resize((size, size), Image.LANCZOS)


def compose_legacy(size):
    bg = gradient_square(size, radius_ratio=0.22)
    mark = aperture_mark(size, radius_frac=0.30)
    bg.alpha_composite(mark)
    return bg


def ensure(path):
    os.makedirs(path, exist_ok=True)


def main():
    for density, size in LAUNCHER.items():
        d = os.path.join(ANDROID_RES, f"mipmap-{density}")
        ensure(d)
        icon = compose_legacy(size)
        icon.save(os.path.join(d, "ic_launcher.png"))
        icon.save(os.path.join(d, "ic_launcher_round.png"))

    for density, size in ADAPTIVE.items():
        d = os.path.join(ANDROID_RES, f"mipmap-{density}")
        ensure(d)
        gradient_square(size).save(
            os.path.join(d, "ic_launcher_background.png"))
        fg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        # Mark sits well inside the 66% adaptive safe zone.
        mark = aperture_mark(size, radius_frac=0.24)
        fg.alpha_composite(mark)
        fg.save(os.path.join(d, "ic_launcher_foreground.png"))

    # Splash logo: the mark over a transparent canvas, one asset scaled by the
    # launch theme. Rendered at a generous size for crisp centring.
    for density, base in {"mdpi": 96, "hdpi": 144, "xhdpi": 192,
                          "xxhdpi": 288, "xxxhdpi": 384}.items():
        d = os.path.join(ANDROID_RES, f"drawable-{density}")
        ensure(d)
        splash = Image.new("RGBA", (base, base), (0, 0, 0, 0))
        splash.alpha_composite(aperture_mark(base, radius_frac=0.42))
        splash.save(os.path.join(d, "wise_splash_logo.png"))

    print("icons generated")


if __name__ == "__main__":
    main()
