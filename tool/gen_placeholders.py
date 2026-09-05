#!/usr/bin/env python3
"""Generate clearly-marked screenshot placeholders for the website.

Per docs/deployment/ASSETS.md and the master prompt: no fake official asset is
committed. These SVG phone frames are obviously placeholders ("Placeholder —
replace with a real capture"), so the site builds and reads intentionally while
the gap stays honest. Replace the files listed in
website/assets/ASSET_MANIFEST.md with real screenshots; keep the same filenames
and the layout is unchanged.

SVG is used because it is a few hundred bytes, sharp at any size, and adds no
raster payload to the Lighthouse budget.

Run:  python3 tool/gen_placeholders.py
"""
import os

WEB = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "website"))
OUT = os.path.join(WEB, "assets", "screenshots")

# 1080 x 2340 is a common phone capture ratio (9 : 19.5).
W, H = 1080, 2340

SHOTS = [
    ("home", "Home", "Three modes: Before · After · Photo"),
    ("match", "Match", "Ghost overlay + alignment guidance"),
    ("check", "Check", "Lighting & focus, advisory only"),
    ("capture", "Capture", "Capture stays possible"),
    ("compare", "Compare", "Side-by-side · slider · overlay · blink"),
    ("measure", "Measure", "After calibration, in physical units"),
    ("export", "Export", "Paired before & after, anonymized"),
    ("reference", "Save Before", "Return later, reproduce it"),
]

APERTURE = (
    '<g transform="translate({cx},{cy}) scale({s})" opacity="0.16">'
    '<g transform="translate(-50,-50)">'
    '<circle cx="50" cy="50" r="30" fill="#F8FAFC"/>'
    '<polygon points="50,34.4 63.51,42.2 63.51,57.8 50,65.6 36.49,57.8 36.49,42.2" fill="#101828"/>'
    '<g stroke="#101828" stroke-width="3.3" stroke-linecap="round">'
    '<line x1="50" y1="34.4" x2="67.11" y2="24.63"/>'
    '<line x1="63.51" y1="42.2" x2="80.53" y2="52.13"/>'
    '<line x1="63.51" y1="57.8" x2="63.41" y2="77.5"/>'
    '<line x1="50" y1="65.6" x2="32.89" y2="75.37"/>'
    '<line x1="36.49" y1="57.8" x2="19.47" y2="47.87"/>'
    '<line x1="36.49" y1="42.2" x2="36.59" y2="22.5"/>'
    '</g></g></g>'
)


def svg(step, title, sub):
    cx, cy = W / 2, H * 0.40
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" role="img" aria-label="{title} screen placeholder">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#101828"/>
      <stop offset="1" stop-color="#243E8F"/>
    </linearGradient>
  </defs>
  <rect width="{W}" height="{H}" fill="url(#bg)"/>
  <rect x="40" y="40" width="{W - 80}" height="{H - 80}" rx="56" fill="none" stroke="#F8FAFC" stroke-opacity="0.10" stroke-width="3"/>
  {APERTURE.format(cx=cx, cy=cy, s=6.0)}
  <text x="{W/2}" y="{H*0.60}" text-anchor="middle" fill="#F8FAFC" font-family="Segoe UI, Roboto, sans-serif" font-size="86" font-weight="700">{step}</text>
  <text x="{W/2}" y="{H*0.65}" text-anchor="middle" fill="#C7D2E5" font-family="Segoe UI, Roboto, sans-serif" font-size="44" font-weight="500">{sub}</text>
  <text x="{W/2}" y="{H*0.90}" text-anchor="middle" fill="#94A3B8" font-family="Segoe UI, Roboto, sans-serif" font-size="38" font-weight="600" letter-spacing="2">PLACEHOLDER — REPLACE WITH REAL CAPTURE</text>
</svg>
'''


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, title, sub in SHOTS:
        with open(os.path.join(OUT, f"{name}.svg"), "w", encoding="utf-8") as f:
            f.write(svg(title, title, sub))
    print(f"{len(SHOTS)} screenshot placeholders written to {OUT}")


if __name__ == "__main__":
    main()
