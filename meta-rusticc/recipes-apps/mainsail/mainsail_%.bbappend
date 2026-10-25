# Mainsail with Rusticc's theme (COSMOS ships it unthemed): a "rusticc" entry
# in Mainsail's theme list (sidebar logo, rust accent #B7410E) as the default
# theme, and the page title, icons and manifest named Rusticc. The images are
# made by branding/make_assets.py.
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI += "file://rusticc-mainsail-theme"

inherit python3native

do_install:append() {
    ${PYTHON} ${UNPACKDIR}/rusticc-mainsail-theme/apply-rusticc-mainsail-theme.py \
        ${D}/var/www/mainsail ${UNPACKDIR}/rusticc-mainsail-theme
}
