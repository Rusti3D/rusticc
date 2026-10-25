#!/usr/bin/env python3
# Make Rusticc's branding assets from branding/Rusticc.png (and the boot logo
# from branding/Rusti3D.png), in the formats and sizes of the COSMOS files they
# replace (meta-opencentauri), into meta-rusticc:
#   boot logo   recipes-data/opencentauri-bootlogos  480x272 / 532x300 24-bit BMP (Rusti3D)
#   psplash     recipes-core/psplash                 480x272 PNG
#   fluidd      recipes-apps/fluidd                  logo SVG, 64x64 icon, 641x72 wordmark
#   mainsail    recipes-apps/mainsail                sidebar logo SVG, 16/32/180 px icons
#   python3 branding/make_assets.py
import base64
import io
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
SRC = HERE / "Rusticc.png"
# the first logo on screen (u-boot), before the Rusticc splash
BOOT_SRC = HERE / "Rusti3D.png"
OUT = HERE.parent / "meta-rusticc"

# Rusticc.png's parts (measured: rows / columns with white pixels)
LETTERS = (147, 265, 1522, 550)  # "RUSTICC"
BLOCK = (147, 265, 1522, 685)  # the letters and the stripes under them
LETTER_R = (147, 265, 362, 550)
STRIPES = (147, 573, 1522, 685)


def fit(im, size, bg=(0, 0, 0)):
    """`im` scaled to fit `size`, centred on `bg`"""
    scale = min(size[0] / im.width, size[1] / im.height)
    w, h = round(im.width * scale), round(im.height * scale)
    out = Image.new(im.mode, size, bg if im.mode == "RGB" else bg + (0,))
    out.paste(im.resize((w, h), Image.LANCZOS), ((size[0] - w) // 2, (size[1] - h) // 2))
    return out


def white_on_clear(im):
    """the white logo on black as white with its brightness as alpha"""
    a = im.convert("L")
    out = Image.new("RGBA", im.size, (255, 255, 255, 0))
    out.putalpha(a)
    return out


def write(path, data):
    path = OUT / path
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    print(path.relative_to(HERE.parent))


def save(im, fmt, **kw):
    b = io.BytesIO()
    im.save(b, fmt, **kw)
    return b.getvalue()


def main():
    logo = Image.open(SRC).convert("RGB")

    # Boot logos (u-boot's bootlogo.bmp: 24-bit, bottom-up, the panel's size):
    # Rusti3D, its transparency on black
    rusti3d = Image.open(BOOT_SRC).convert("RGBA")
    boot_logo = Image.new("RGB", rusti3d.size, (0, 0, 0))
    boot_logo.paste(rusti3d, mask=rusti3d.getchannel("A"))
    boot = "recipes-data/opencentauri-bootlogos/files"
    write(f"{boot}/centauri-carbon-1/bootlogo.bmp", save(fit(boot_logo, (480, 272)), "BMP"))
    write(f"{boot}/centauri-carbon-2/bootlogo.bmp", save(fit(boot_logo, (532, 300)), "BMP"))

    # The psplash boot splash
    write("recipes-core/psplash/files/rusticc_1.png", save(fit(logo, (480, 272)).convert("RGBA"), "PNG"))

    # Fluidd: the theme logo (an SVG around the PNG of the logo block),
    # the icon (the R over a strip of the stripes) and the wordmark
    fluidd = "recipes-apps/fluidd/files/rusticc-fluidd-theme"
    block = white_on_clear(logo.crop(BLOCK))
    block = block.resize((block.width // 2, block.height // 2), Image.LANCZOS)
    png = base64.b64encode(save(block, "PNG", optimize=True)).decode()
    svg = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
        f'width="{block.width}" height="{block.height}" viewBox="0 0 {block.width} {block.height}">\n'
        f'<title>Rusticc</title>\n'
        f'<image width="{block.width}" height="{block.height}" xlink:href="data:image/png;base64,{png}"/>\n'
        "</svg>\n"
    )
    write(f"{fluidd}/logo_opencentauri.svg", svg.encode())

    r = logo.crop(LETTER_R)
    stripes = logo.crop(STRIPES).crop((0, 0, r.width, STRIPES[3] - STRIPES[1]))
    icon = Image.new("RGB", (r.width, r.height + 24 + stripes.height))
    icon.paste(r, (0, 0))
    icon.paste(stripes, (0, r.height + 24))
    write(f"{fluidd}/carbon-logo-red.webp", save(fit(icon, (64, 64)), "WEBP", lossless=True))

    letters = white_on_clear(logo.crop(LETTERS))
    write(f"{fluidd}/opencentauri-logo-small.png", save(fit(letters, (641, 72), (255, 255, 255)), "PNG", optimize=True))

    # Mainsail: the theme's sidebar logo (the Fluidd logo SVG) and the icons
    # in the sizes Mainsail ships (img/icons)
    mainsail = "recipes-apps/mainsail/files/rusticc-mainsail-theme"
    write(f"{mainsail}/sidebarLogo-rusticc.svg", svg.encode())
    for name, size in (("favicon-16x16.png", 16), ("favicon-32x32.png", 32), ("apple-touch-icon-180x180.png", 180)):
        write(f"{mainsail}/{name}", save(fit(icon, (size, size)), "PNG", optimize=True))


if __name__ == "__main__":
    main()
