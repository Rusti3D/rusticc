# Fluidd with Rusticc's theme: COSMOS's theme (opencentauri-fluidd-theme)
# named Rusticc, with Rusticc's logo, icon and wordmark (same file names,
# made by branding/make_assets.py)
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI += "file://rusticc-fluidd-theme"

do_install:prepend() {
    theme=${UNPACKDIR}/opencentauri-fluidd-theme
    cp ${UNPACKDIR}/rusticc-fluidd-theme/* $theme/
    sed -i -e 's/OpenCentauri/Rusticc/g' \
        $theme/apply-opencentauri-fluidd-theme.py $theme/opencentauri-theme.css
}
