#!/usr/bin/env python3
"""Validate the WISE Clinical Camera website before it ships.

Fails (non-zero exit) if:
  * a referenced local asset (href/src/icon/manifest) does not exist
  * the Android download configuration is missing
  * the canonical domain is missing or malformed
  * required SEO / social / icon metadata is absent from index.html
  * a config JSON file is missing, invalid, or missing a required key
  * the web manifest is invalid or points at a missing icon
  * the CNAME does not match the configured domain

Pure standard library so it runs anywhere (locally and in CI) with no install.

Usage:  python3 tool/validate_website.py
"""
import json
import os
import re
import sys
from html.parser import HTMLParser

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
WEB = os.path.join(ROOT, "website")
EXPECTED_DOMAIN = "camera.wishomeopathy.com"

errors = []
warnings = []
checks = 0


def err(msg):
    errors.append(msg)


def warn(msg):
    warnings.append(msg)


def ok(msg):
    global checks
    checks += 1


def is_external(url):
    return (
        url.startswith("http://")
        or url.startswith("https://")
        or url.startswith("//")
        or url.startswith("#")
        or url.startswith("mailto:")
        or url.startswith("tel:")
        or url.startswith("data:")
    )


class RefCollector(HTMLParser):
    """Collect local href/src/content-url references and meta tags."""

    def __init__(self):
        super().__init__()
        self.local_refs = []       # (attr, url)
        self.metas = []            # dict of attrs for every <meta>
        self.links = []            # dict of attrs for every <link>
        self.has_title = False
        self.has_h1 = False
        self._in_title = False
        self.title_text = ""

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == "title":
            self._in_title = True
            self.has_title = True
        if tag == "h1":
            self.has_h1 = True
        if tag == "meta":
            self.metas.append(a)
        if tag == "link":
            self.links.append(a)
            href = a.get("href")
            if href and not is_external(href):
                self.local_refs.append(("href", href))
        for attr in ("src", "href"):
            v = a.get(attr)
            if v and not is_external(v):
                self.local_refs.append((attr, v))

    def handle_endtag(self, tag):
        if tag == "title":
            self._in_title = False

    def handle_data(self, data):
        if self._in_title:
            self.title_text += data


def parse_html(path):
    with open(path, encoding="utf-8") as f:
        content = f.read()
    p = RefCollector()
    p.feed(content)
    return p, content


def check_local_refs(page_path, parser):
    base = os.path.dirname(page_path)
    for attr, url in parser.local_refs:
        clean = url.split("#", 1)[0].split("?", 1)[0]
        if not clean:
            continue
        target = os.path.normpath(os.path.join(base, clean))
        if not os.path.exists(target):
            err(f"{os.path.relpath(page_path, ROOT)}: {attr}=\"{url}\" -> missing file {os.path.relpath(target, ROOT)}")
        else:
            ok(f"ref {url}")


def get_meta(metas, key, keyattr="name"):
    for m in metas:
        if m.get(keyattr) == key:
            return m.get("content")
    return None


def validate_index():
    path = os.path.join(WEB, "index.html")
    if not os.path.exists(path):
        err("website/index.html is missing")
        return
    parser, content = parse_html(path)

    # Required metadata
    if not parser.has_title or not parser.title_text.strip():
        err("index.html: <title> is missing or empty")
    else:
        ok("title")
    if not parser.has_h1:
        err("index.html: no <h1> heading found")
    else:
        ok("h1")

    desc = get_meta(parser.metas, "description")
    if not desc or len(desc.strip()) < 40:
        err("index.html: meta description missing or too short")
    else:
        ok("description")

    if not get_meta(parser.metas, "theme-color"):
        err("index.html: <meta name=theme-color> missing")
    else:
        ok("theme-color")

    # canonical
    canonical = None
    for l in parser.links:
        if l.get("rel") == "canonical":
            canonical = l.get("href")
    if not canonical:
        err("index.html: <link rel=canonical> missing")
    elif EXPECTED_DOMAIN not in canonical:
        err(f"index.html: canonical URL '{canonical}' does not contain {EXPECTED_DOMAIN}")
    elif not re.match(r"^https://" + re.escape(EXPECTED_DOMAIN) + r"/?", canonical):
        err(f"index.html: canonical URL '{canonical}' is malformed (expected https://{EXPECTED_DOMAIN}/)")
    else:
        ok("canonical")

    # Open Graph + Twitter
    for prop in ("og:title", "og:description", "og:image", "og:url", "og:type"):
        if not get_meta(parser.metas, prop, "property"):
            err(f"index.html: Open Graph tag '{prop}' missing")
        else:
            ok(prop)
    if not get_meta(parser.metas, "twitter:card"):
        err("index.html: twitter:card missing")
    else:
        ok("twitter:card")

    og_image = get_meta(parser.metas, "og:image", "property")
    if og_image and EXPECTED_DOMAIN not in og_image:
        warn(f"index.html: og:image '{og_image}' is not an absolute URL on {EXPECTED_DOMAIN}")

    # favicon + manifest + apple-touch
    rels = [l.get("rel") for l in parser.links]
    if not any(r == "icon" for r in rels):
        err("index.html: no favicon <link rel=icon>")
    else:
        ok("favicon")
    if "manifest" not in rels:
        err("index.html: <link rel=manifest> missing")
    else:
        ok("manifest link")
    if "apple-touch-icon" not in rels:
        warn("index.html: apple-touch-icon link missing")

    # structured data
    if "application/ld+json" not in content:
        warn("index.html: no JSON-LD structured data found")
    else:
        ok("structured-data")

    check_local_refs(path, parser)


def validate_other_pages():
    for name in ("privacy.html", "404.html"):
        path = os.path.join(WEB, name)
        if not os.path.exists(path):
            warn(f"website/{name} is missing")
            continue
        parser, _ = parse_html(path)
        if not parser.has_title:
            err(f"{name}: <title> missing")
        else:
            ok(f"{name} title")
        check_local_refs(path, parser)


def validate_downloads():
    path = os.path.join(WEB, "config", "downloads.json")
    if not os.path.exists(path):
        err("config/downloads.json missing")
        return
    try:
        with open(path, encoding="utf-8") as f:
            dl = json.load(f)
    except json.JSONDecodeError as e:
        err(f"config/downloads.json is invalid JSON: {e}")
        return

    for key in ("version", "channel", "releasesUrl", "android", "ios"):
        if key not in dl:
            err(f"downloads.json: required key '{key}' missing")
        else:
            ok(f"downloads.{key}")

    android = dl.get("android", {})
    # Android must resolve to *something*: an explicit url when available, else releasesUrl.
    android_target = (android.get("url") if android.get("available") else None) or dl.get("releasesUrl")
    if not android_target:
        err("downloads.json: no Android download location (android.url or releasesUrl)")
    else:
        ok("android target")
    if android.get("available") and not android.get("url"):
        err("downloads.json: android.available is true but android.url is empty")

    ios = dl.get("ios", {})
    if ios.get("available") and not ios.get("url"):
        err("downloads.json: ios.available is true but ios.url is empty")

    for name, url in (("releasesUrl", dl.get("releasesUrl")),
                      ("android.url", android.get("url")),
                      ("ios.url", ios.get("url"))):
        if url and not re.match(r"^https://", url):
            err(f"downloads.json: {name} '{url}' must be an https URL")


def validate_site():
    path = os.path.join(WEB, "config", "site.json")
    if not os.path.exists(path):
        err("config/site.json missing")
        return
    try:
        with open(path, encoding="utf-8") as f:
            site = json.load(f)
    except json.JSONDecodeError as e:
        err(f"config/site.json is invalid JSON: {e}")
        return
    domain = site.get("domain")
    if domain != EXPECTED_DOMAIN:
        err(f"site.json: domain '{domain}' != expected '{EXPECTED_DOMAIN}'")
    else:
        ok("site.domain")
    canonical = site.get("canonicalUrl", "")
    if EXPECTED_DOMAIN not in canonical:
        err(f"site.json: canonicalUrl '{canonical}' does not contain {EXPECTED_DOMAIN}")
    else:
        ok("site.canonicalUrl")
    if not site.get("urls", {}).get("repo"):
        err("site.json: urls.repo missing")
    else:
        ok("site.urls.repo")


def validate_manifest():
    path = os.path.join(WEB, "site.webmanifest")
    if not os.path.exists(path):
        err("site.webmanifest missing")
        return
    try:
        with open(path, encoding="utf-8") as f:
            man = json.load(f)
    except json.JSONDecodeError as e:
        err(f"site.webmanifest invalid JSON: {e}")
        return
    for key in ("name", "short_name", "icons", "theme_color", "background_color", "display"):
        if key not in man:
            err(f"site.webmanifest: '{key}' missing")
        else:
            ok(f"manifest.{key}")
    for icon in man.get("icons", []):
        src = icon.get("src")
        if src and not is_external(src):
            target = os.path.normpath(os.path.join(WEB, src))
            if not os.path.exists(target):
                err(f"site.webmanifest: icon missing on disk: {src}")
            else:
                ok(f"manifest icon {src}")


def validate_assets_json():
    path = os.path.join(WEB, "assets", "assets.json")
    if not os.path.exists(path):
        err("assets/assets.json missing")
        return
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        err(f"assets/assets.json invalid JSON: {e}")
        return
    count = 0
    for group in ("brand", "screenshots", "posters"):
        for entry in data.get(group, []):
            p = entry.get("path")
            if not p:
                continue
            target = os.path.normpath(os.path.join(WEB, p))
            count += 1
            if not os.path.exists(target):
                err(f"assets.json: listed asset missing on disk: {p}")
            else:
                ok(f"asset {p}")
    if count == 0:
        warn("assets.json: no assets listed")


def validate_deploy_files():
    cname = os.path.join(WEB, "CNAME")
    if not os.path.exists(cname):
        err("website/CNAME missing")
    else:
        with open(cname, encoding="utf-8") as f:
            val = f.read().strip()
        if val != EXPECTED_DOMAIN:
            err(f"CNAME contains '{val}', expected '{EXPECTED_DOMAIN}'")
        else:
            ok("CNAME")
    if not os.path.exists(os.path.join(WEB, ".nojekyll")):
        warn("website/.nojekyll missing (recommended for GitHub Pages)")
    else:
        ok(".nojekyll")
    for f in ("robots.txt", "sitemap.xml"):
        if not os.path.exists(os.path.join(WEB, f)):
            warn(f"website/{f} missing")
        else:
            ok(f)


def main():
    if not os.path.isdir(WEB):
        print("ERROR: website/ directory not found", file=sys.stderr)
        sys.exit(2)

    validate_index()
    validate_other_pages()
    validate_downloads()
    validate_site()
    validate_manifest()
    validate_assets_json()
    validate_deploy_files()

    print(f"Ran {checks} checks.")
    if warnings:
        print(f"\n{len(warnings)} warning(s):")
        for w in warnings:
            print(f"  ⚠ {w}")
    if errors:
        print(f"\n{len(errors)} error(s):", file=sys.stderr)
        for e in errors:
            print(f"  ✗ {e}", file=sys.stderr)
        print("\nWEBSITE VALIDATION FAILED", file=sys.stderr)
        sys.exit(1)
    print("\n✓ Website validation passed.")


if __name__ == "__main__":
    main()
