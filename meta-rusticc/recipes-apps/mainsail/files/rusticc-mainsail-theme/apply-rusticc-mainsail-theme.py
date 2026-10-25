#!/usr/bin/env python3
# Rusticc's theme for Mainsail (2.19.0, COSMOS's version), applied to the
# installed web root as COSMOS applies its Fluidd theme: a "rusticc" entry in
# Mainsail's built-in theme list (its sidebar logo and rust accent), made the
# default theme; the page title, icons and manifest name Rusticc, and the
# texts naming the API server say Moonruster. Every edit
# must find its anchor: another Mainsail version fails here, not silently.
#   apply-rusticc-mainsail-theme.py <webroot> <theme files dir>
import hashlib
import json
import re
import shutil
import sys
from pathlib import Path

APP_NAME = "Rusticc"
DESCRIPTION = "Rusticc web interface for the Elegoo Centauri Carbon"
PRIMARY_COLOR = "#B7410E"
THEME_ENTRY = (
    "{name:`rusticc`,displayName:`Rusticc`,colorLogo:`%s`,colorPrimary:`%s`,logo:{show:!0,light:!1}},"
    % (PRIMARY_COLOR, PRIMARY_COLOR)
)
ANCHOR = "{name:`klipper`,displayName:`Klipper`,"


def sub_once(text, pattern, repl, path):
    new, n = re.subn(pattern, repl, text, count=1)
    if n != 1:
        raise RuntimeError(f"{path}: expected text not found: {pattern[:80]!r}")
    return new


def add_theme(webroot):
    hits = [p for p in (webroot / "assets").glob("*.js") if ANCHOR in p.read_text(encoding="utf-8")]
    if len(hits) != 1:
        raise RuntimeError(f"the theme list is in {len(hits)} bundles, expected 1")
    path = hits[0]
    text = path.read_text(encoding="utf-8")
    if "name:`rusticc`" not in text:
        text = text.replace(ANCHOR, THEME_ENTRY + ANCHOR, 1)
        path.write_text(text, encoding="utf-8")


def set_default_theme(webroot):
    path = webroot / "config.json"
    config = json.loads(path.read_text(encoding="utf-8"))
    config["defaultTheme"] = "rusticc"
    path.write_text(json.dumps(config, indent=4) + "\n", encoding="utf-8")


def patch_index_html(webroot):
    path = webroot / "index.html"
    text = path.read_text(encoding="utf-8")
    text = sub_once(text, r"<title>[^<]*</title>", f"<title>{APP_NAME}</title>", path)
    text = sub_once(text, r'<meta name="description" content="[^"]*" />',
                    f'<meta name="description" content="{DESCRIPTION}" />', path)
    text = sub_once(text, r'<meta name="apple-mobile-web-app-title" content="[^"]*" />',
                    f'<meta name="apple-mobile-web-app-title" content="{APP_NAME}" />', path)
    text = sub_once(text, r'(<link rel="mask-icon" href="[^"]*" color=")[^"]*(")', rf"\g<1>{PRIMARY_COLOR}\2", path)
    text = sub_once(text, r'<meta name="msapplication-TileColor" content="[^"]*" />',
                    f'<meta name="msapplication-TileColor" content="{PRIMARY_COLOR}" />', path)
    path.write_text(text, encoding="utf-8")


def add_panel_loader(webroot):
    # The panel extender's loader (served from /addons by Moonruster's
    # addons_path): Rusticc's timelapse panels and other addons' panels
    path = webroot / "index.html"
    text = path.read_text(encoding="utf-8")
    text = sub_once(text, r"</head>", '<script src="/addons/loader.js" defer></script></head>', path)
    path.write_text(text, encoding="utf-8")


# The service worker precaches Mainsail's files by revision (their md5, or
# null for the hash-named bundles): a file edited here keeps its old
# revision, and a browser that cached Mainsail keeps serving the old copy.
# Every precached file this script changes gets its new md5 as revision.
PRECACHE_ENTRY = r'\{url:"([^"]+)",revision:(?:"[0-9a-f]*"|null)\}'


def md5s(webroot):
    sw = (webroot / "sw.js").read_text(encoding="utf-8")
    out = {}
    for url in re.findall(PRECACHE_ENTRY, sw):
        f = webroot / url
        if f.is_file():
            out[url] = hashlib.md5(f.read_bytes()).hexdigest()
    return out


def bump_precache(webroot, before):
    path = webroot / "sw.js"
    sw = path.read_text(encoding="utf-8")
    after = md5s(webroot)
    changed = [u for u in after if after[u] != before.get(u)]
    if "index.html" not in changed:
        raise RuntimeError("sw.js: index.html not found in the precache list")
    for url in changed:
        sw = sub_once(sw, r'\{url:"%s",revision:(?:"[0-9a-f]*"|null)\}' % re.escape(url),
                      '{url:"%s",revision:"%s"}' % (url, after[url]), path)
    path.write_text(sw, encoding="utf-8")


def patch_manifest(webroot):
    path = webroot / "manifest.webmanifest"
    manifest = json.loads(path.read_text(encoding="utf-8"))
    manifest["name"] = APP_NAME
    manifest["short_name"] = APP_NAME
    manifest["description"] = DESCRIPTION
    manifest["theme_color"] = PRIMARY_COLOR
    path.write_text(json.dumps(manifest, separators=(",", ":")), encoding="utf-8")


# Rusticc's API server is Moonruster: the English texts that name the server,
# and the labels Mainsail writes itself. Keys, the moonraker.conf file name,
# service and component names are left as they are.
SERVER_NAME = "Moonruster"
EN_SERVER_TEXTS = 12
SERVER_LABELS = (
    "this.moonrakerInstance?`Moonraker`:",
    "{service:`Moonraker`}",
    "serviceName:`Moonraker`",
)


def name_server(webroot):
    en = list((webroot / "assets").glob("en-*.js"))
    if len(en) != 1:
        raise RuntimeError(f"the English locale is in {len(en)} bundles, expected 1")
    text = en[0].read_text(encoding="utf-8")
    # "Moonraker" as a word: not a key such as MoonrakerLog
    text, n = re.subn(r"(?<![A-Za-z_])Moonraker(?![A-Za-z_])", SERVER_NAME, text)
    if n != EN_SERVER_TEXTS:
        raise RuntimeError(f"{en[0]}: {n} English texts name Moonraker, expected {EN_SERVER_TEXTS}")
    en[0].write_text(text, encoding="utf-8")
    for label in SERVER_LABELS:
        hits = [p for p in (webroot / "assets").glob("index-*.js") if label in p.read_text(encoding="utf-8")]
        if len(hits) != 1:
            raise RuntimeError(f"{label!r}: in {len(hits)} bundles, expected 1")
        text = hits[0].read_text(encoding="utf-8")
        if text.count(label) != 1:
            raise RuntimeError(f"{hits[0]}: {label!r} {text.count(label)} times, expected 1")
        hits[0].write_text(text.replace(label, label.replace("Moonraker", SERVER_NAME)), encoding="utf-8")


def install_files(webroot, files):
    shutil.copy(files / "sidebarLogo-rusticc.svg", webroot / "img/themes/sidebarLogo-rusticc.svg")
    for name in ("favicon-16x16.png", "favicon-32x32.png", "apple-touch-icon-180x180.png"):
        if not (webroot / "img/icons" / name).exists():
            raise RuntimeError(f"img/icons/{name}: not in this Mainsail")
        shutil.copy(files / name, webroot / "img/icons" / name)


def main():
    webroot, files = Path(sys.argv[1]), Path(sys.argv[2])
    before = md5s(webroot)
    add_theme(webroot)
    set_default_theme(webroot)
    patch_index_html(webroot)
    patch_manifest(webroot)
    name_server(webroot)
    install_files(webroot, files)
    add_panel_loader(webroot)
    bump_precache(webroot, before)


if __name__ == "__main__":
    main()
