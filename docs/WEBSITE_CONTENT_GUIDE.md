# Website Content Guide

For updating the WISE Clinical Camera website **without writing code**. Almost
everything you'll want to change lives in two JSON files and the asset folders —
you should rarely need to open `index.html`.

- Two config files: `website/config/downloads.json`, `website/config/site.json`
- Assets: `website/assets/…` (indexed by `website/assets/ASSET_MANIFEST.md`)
- After **any** change, run the checker: `python3 tool/validate_website.py`

> Editing JSON: keep the quotes and commas exactly as they are. A missing comma
> or quote breaks the file — the validator will tell you if you slip.

---

## Replace a screenshot

1. Take the screenshot on a phone (portrait; ~9 : 19.5, e.g. 1080×2340).
2. Save it over the matching placeholder in `website/assets/screenshots/`,
   keeping the **same filename** (e.g. `match.svg` → replace with your capture).
   - Easiest: keep the `.svg` name only if your file is SVG. For a PNG/WebP,
     name it e.g. `match.webp`, then update that one `src` in `index.html` and
     the entry in `website/assets/assets.json`.
3. `python3 tool/validate_website.py`
4. Commit and push.

Which file is which screen is listed in `ASSET_MANIFEST.md`.

---

## Replace the poster

Replace `website/assets/posters/app-poster.svg` (landscape, ~16 : 10). Same
filename, then validate, commit, push.

---

## Replace the logo / app icon

The website logo and icons are **generated from the app's aperture mark** so the
site and the app never look different. To change them:

1. Edit the mark in `tool/gen_web_assets.py` (and `website/assets/brand/favicon.svg`
   for the vector master).
2. Run `python3 tool/gen_web_assets.py`.
3. Validate, commit, push.

Do not hand-edit the generated PNGs — they'd drift from the app icon.

---

## Update the Android download link

Edit **`website/config/downloads.json`** only:

```json
"version": "1.0.0",
"channel": "Preview",
"releaseDate": "2026-01-15",
"android": { "available": true, "url": "https://github.com/…/releases/download/v1.0.0/app.apk" }
```

Set `android.available` to `true` and paste the release asset URL. Leaving
`url` empty falls back to the releases page. Validate, commit, push. The version
and channel shown on the page update automatically.

---

## Add the iOS link

In the same file, when a real link exists:

```json
"ios": { "available": true, "url": "https://apps.apple.com/app/id0000000000" }
```

The "iOS — Coming soon" button becomes an active App Store button. Never invent
a URL — leave `available` as `false` until a real link exists.

---

## Update version information

`version`, `channel` and `releaseDate` in `downloads.json` drive the version
text in the hero and the download card. Change them there; nowhere else.

---

## Update release notes / support contact / links

- Support, GitHub, docs and privacy links live in `website/config/site.json`
  under `urls`. Update them there.
- Social profile links are in `site.json` under `social` — empty strings are
  hidden on the page, so add a URL only when a real profile exists.

---

## Preview locally

No build step. Serve the folder and open it:

```bash
cd website
python3 -m http.server 8000
# then open http://localhost:8000
```

A plain file open (`file://`) mostly works, but the `config/*.json` fetch needs
a server — so use the command above to see live download links and version.

---

## How it deploys

Pushing to `main` with changes under `website/` triggers the **Deploy website**
GitHub Action, which validates the site and publishes it to GitHub Pages. Full
detail — including the custom domain and DNS — is in
[`WEBSITE_DEPLOYMENT.md`](WEBSITE_DEPLOYMENT.md).

---

## The golden rule

If you find yourself editing `index.html` to change a link, a version or an
image, stop — there is almost certainly a config field or a named asset file for
it. Keeping content in config and assets is what lets a non-developer maintain
the site safely.
