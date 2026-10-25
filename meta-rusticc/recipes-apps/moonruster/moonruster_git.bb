SUMMARY = "Rusticc's Moonraker: Moonruster with COSMOS's patches"
DESCRIPTION = "Moonruster (Moonraker ported to Rust) with Rusticc's patches: COSMOS's Moonraker additions (SWUpdate updates, 5 MB log rotation, static web client, webcam ports, sysvinit provider); python components run on the image's CPython."
HOMEPAGE = "https://github.com/Rusti3D/moonruster"
LICENSE = "GPL-3.0-only"
LIC_FILES_CHKSUM = "file://Cargo.toml;beginline=6;endline=6;md5=a74e7d3482a2d6f20b33af57f6e99553"

# Moonruster (branch plugins until it merges into main) with Rusticc's
# patches, as COSMOS builds Moonraker with its own: files/moonruster, listed
# by moonruster-patches.inc (tools/moonruster-tree.sh / moonruster-export.sh)
SRC_URI = "git://github.com/Rusti3D/moonruster.git;protocol=https;branch=plugins"
SRCREV = "df8eee16013839ed0af9f99cc6a8fa86422c76f4"
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
