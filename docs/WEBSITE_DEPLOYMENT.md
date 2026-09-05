# Website Deployment

How the WISE Clinical Camera public website (`website/`) is built, deployed to
GitHub Pages, and pointed at `camera.wishomeopathy.com`.

- **Source of truth:** the `website/` folder on the `main` branch.
- **Hosting:** GitHub Pages, deployed by GitHub Actions
  (`.github/workflows/pages.yml`) — no `gh-pages` branch to maintain.
- **Intended URL:** <https://camera.wishomeopathy.com>
- **Fallback URL:** the project Pages URL,
  `https://ihkarise.github.io/WISE-CLINICAL-CAMERA/` (works because every asset
  path in the site is relative).

---

## 1. GitHub Pages setup (one time)

1. Merge the website to `main`.
2. Repository → **Settings → Pages**.
3. Under **Build and deployment → Source**, choose **GitHub Actions**.
   (Do *not* choose "Deploy from a branch" — this project uses the Actions
   workflow so only `website/` is published, never the app or the docs.)
4. Push any change under `website/` (or run the **Deploy website** workflow
   manually via *Actions → Deploy website → Run workflow*). The workflow
   validates the site, then uploads and deploys the `website/` folder.
5. The first successful run prints the live Pages URL in the workflow summary.

The workflow triggers on pushes to `main` that touch `website/**` (or the
workflow file), and on manual dispatch. It runs `tool/validate_website.py`
first and refuses to deploy if validation fails.

---

## 2. Custom domain setup

The repository already contains `website/CNAME` with `camera.wishomeopathy.com`,
so GitHub associates the domain automatically on deploy. To finish activation:

1. Add the DNS record in step 3 at the `wishomeopathy.com` DNS provider.
2. Repository → **Settings → Pages → Custom domain**: confirm
   `camera.wishomeopathy.com` is shown (it is read from the CNAME file).
3. Wait for the DNS check to pass, then tick **Enforce HTTPS**.

> The domain is **not** live until DNS resolves and the GitHub Pages check
> passes. Do not announce the domain before verifying both.

---

## 3. DNS records required

`camera` is a subdomain, so use a **CNAME** record (not an A record):

| Type  | Name (host) | Value                   | TTL     |
|-------|-------------|-------------------------|---------|
| CNAME | `camera`    | `ihkarise.github.io.`   | 3600    |

- The value is the **user** Pages host (`<owner>.github.io`), *not* the project
  path — this is correct for a project site served under a custom subdomain.
- Some providers want the value without the trailing dot; both usually work.
- If the provider offers CAA records, ensure `letsencrypt.org` is permitted so
  GitHub can issue the TLS certificate.

Verify from a terminal once propagated:

```bash
dig +short camera.wishomeopathy.com CNAME     # -> ihkarise.github.io.
curl -sI https://camera.wishomeopathy.com | head -n1
```

---

## 4. HTTPS expectations

GitHub Pages provisions a free Let's Encrypt certificate automatically once the
custom domain's DNS check passes. This can take a few minutes to a few hours
after the DNS record resolves. Leave **Enforce HTTPS** enabled. No certificate
management is required.

---

## 5. Android download update process

Everything lives in one file: **`website/config/downloads.json`**.

1. Publish the APK as a **GitHub Release** asset (see §9 below).
2. Edit `website/config/downloads.json`:
   - set `android.available` to `true`
   - set `android.url` to the release asset URL (or keep it empty to fall back
     to `releasesUrl`, which always points at the releases page)
   - update `version`, `releaseDate`, and `channel` (`Preview`, `Beta`, or a
     production label once signing is complete)
3. Run `python3 tool/validate_website.py`.
4. Commit and push to `main` — the site redeploys automatically.

No HTML editing is ever required to change a download link.

---

## 6. iOS download update process

Also `website/config/downloads.json`:

1. When a real TestFlight or App Store link exists, set `ios.available` to
   `true` and `ios.url` to that link.
2. Run the validator, commit, push. The "Coming soon" button becomes an active
   "Download on the App Store" button automatically.

Never invent an App Store URL. While `ios.available` is `false`, the site shows
"iOS — Coming soon".

---

## 7. Asset update process

See **`website/assets/ASSET_MANIFEST.md`** for the authoritative list. In short:

1. Drop the new file into the matching `website/assets/…` folder, keeping the
   documented filename (real screenshots replace the placeholders 1-for-1).
2. Brand icons are generated — change `tool/gen_web_assets.py` and re-run it
   rather than hand-editing PNGs, so the site stays in step with the app icon.
3. Run `python3 tool/validate_website.py` (fails if any referenced asset is
   missing).
4. Commit and push.

---

## 8. Rollback process

Any of the following, in order of convenience:

- **Re-run a previous deployment:** *Actions → Deploy website* → open a
  previously green run → **Re-run all jobs**. Pages redeploys that commit's
  site.
- **Revert the commit:** `git revert <sha>` on `main` and push; the workflow
  redeploys the reverted state.
- **Roll back a link only:** edit `website/config/downloads.json` back to the
  previous values and push (fastest fix for a bad download link — no rebuild of
  content needed).

---

## 9. Preparing a stable Android release (recommended)

The public site should link to a **stable GitHub Release asset**, never an
expiring GitHub Actions artifact.

1. Build the APK (`flutter build apk --release`; use `--debug` only for an early
   internal preview).
2. Repository → **Releases → Draft a new release**; tag e.g. `v1.0.0-preview`.
3. Attach the APK (e.g. `wise-clinical-camera-1.0.0-preview.apk`).
4. Because production signing is not yet complete, keep the release marked as a
   **pre-release** and label the channel `Preview` in `downloads.json`. Do not
   present it as a production store build.
5. Point `downloads.json` at the release (§5).

Until a release exists, the Android button links to the releases page, which is
honest and never dead.
