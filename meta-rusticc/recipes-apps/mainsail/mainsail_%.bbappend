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

# The Mainsail Panel Extender (from cosmoace_afc, with page panels) in
# /var/www/addons, which Moonruster serves at /addons (addons_path, next to
# /user-resource/webui-addons for runtime-installed addons); the theme
# script adds its <script> to index.html. Rusticc's timelapse panels
# (panels/timelapse) are not installed until timelapse is finished
# (docs/TIMELAPSE.md).
SRC_URI += "file://panel-extender"
do_install:append() {
    install -d ${D}/var/www/addons/panels
    install -m 0644 ${UNPACKDIR}/panel-extender/loader.js ${D}/var/www/addons/
}
FILES:${PN} += "/var/www/addons"
