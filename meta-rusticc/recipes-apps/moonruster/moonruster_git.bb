SUMMARY = "Rusticc's Moonraker: Moonruster with COSMOS's patches"
DESCRIPTION = "Moonruster (Moonraker ported to Rust) with Rusticc's patches: COSMOS's Moonraker additions (SWUpdate updates, 5 MB log rotation, static web client, webcam ports, sysvinit provider)."
HOMEPAGE = "https://github.com/Rusti3D/moonruster"
LICENSE = "GPL-3.0-only"
LIC_FILES_CHKSUM = "file://LICENSE;md5=db95b6e40dc7d26d8308b6b7375637b6"

# Moonruster (main) with Rusticc's
# patches, as COSMOS builds Moonraker with its own: files/moonruster, listed
# by moonruster-patches.inc (tools/moonruster-tree.sh / moonruster-export.sh)
SRC_URI = "git://github.com/Rusti3D/moonruster.git;protocol=https;branch=main"
SRCREV = "724e081318387d764635fce7863ae2fa6eb4c37c"
PV = "0.1.0+git"

require moonruster-patches.inc
require moonruster-crates.inc

inherit cargo

# the plugins feature (default): python components on the image's
# libpython (dlopen'ed: no link dependency); non-PIE
CARGO_BUILD_FLAGS += "--bin moonruster"
RUSTFLAGS:append = " -C relocation-model=static"
# (the image strips: an already stripped binary is a QA error)
export CARGO_PROFILE_RELEASE_STRIP = "false"

RDEPENDS:${PN} = "libpython3"

# The default allowed-services list moonraker-init-d compares the overlay's
# copy with (Moonruster embeds the same file)
do_install:append() {
    install -d ${D}${datadir}/moonruster
    install -m 0644 ${S}/assets/default_allowed_services ${D}${datadir}/moonruster/
}
FILES:${PN} += "${datadir}/moonruster"
