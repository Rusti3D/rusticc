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
    # Rusticc's rust accent (Mainsail's too) in place of COSMOS's light grey
    sed -i -e 's/PRIMARY_COLOR = "#D8DADC"/PRIMARY_COLOR = "#B7410E"/' $theme/apply-opencentauri-fluidd-theme.py
    sed -i -e 's/--oc-primary: #d8dadc;/--oc-primary: #b7410e;/' \
        -e 's/--oc-primary-muted: #aeb2b6;/--oc-primary-muted: #8f330b;/' \
        -e 's/--v-primary-lighten1: #eeeeee;/--v-primary-lighten1: #c5673e;/' \
        -e 's/--v-primary-darken1: #aeb2b6;/--v-primary-darken1: #8f330b;/' \
        -e 's/--v-primary-offset-base: #aeb2b6;/--v-primary-offset-base: #8f330b;/' $theme/opencentauri-theme.css
}
