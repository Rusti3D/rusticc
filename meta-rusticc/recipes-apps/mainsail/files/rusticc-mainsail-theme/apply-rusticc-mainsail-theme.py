#!/usr/bin/env python3
# Rusticc's theme for Mainsail (2.19.0, COSMOS's version), applied to the
# installed web root as COSMOS applies its Fluidd theme: a "rusticc" entry in
# Mainsail's built-in theme list (its sidebar logo and rust accent), made the
# default theme; the page title, icons and manifest name Rusticc. Every edit
# must find its anchor: another Mainsail version fails here, not silently.
#   apply-rusticc-mainsail-theme.py <webroot> <theme files dir>
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


def patch_manifest(webroot):
    path = webroot / "manifest.webmanifest"
    manifest = json.loads(path.read_text(encoding="utf-8"))
    manifest["name"] = APP_NAME
    manifest["short_name"] = APP_NAME
    manifest["description"] = DESCRIPTION
    manifest["theme_color"] = PRIMARY_COLOR
    path.write_text(json.dumps(manifest, separators=(",", ":")), encoding="utf-8")


def install_files(webroot, files):
    shutil.copy(files / "sidebarLogo-rusticc.svg", webroot / "img/themes/sidebarLogo-rusticc.svg")
    for name in ("favicon-16x16.png", "favicon-32x32.png", "apple-touch-icon-180x180.png"):
        if not (webroot / "img/icons" / name).exists():
            raise RuntimeError(f"img/icons/{name}: not in this Mainsail")
        shutil.copy(files / name, webroot / "img/icons" / name)


def main():
    webroot, files = Path(sys.argv[1]), Path(sys.argv[2])
    add_theme(webroot)
    set_default_theme(webroot)
    patch_index_html(webroot)
    patch_manifest(webroot)
    install_files(webroot, files)


if __name__ == "__main__":
    main()
