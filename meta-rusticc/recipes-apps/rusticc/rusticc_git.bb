SUMMARY = "Rusticc klippy: Kalico with COSMOS's patches, in Rust"
DESCRIPTION = "kaliru (Kalico ported to Rust) with Rusticc's patches: COSMOS's klippy without the embedded RustPython; python plugins and macros run on the image's CPython."
HOMEPAGE = "https://github.com/Rusti3D/kaliru"
LICENSE = "GPL-3.0-only"
LIC_FILES_CHKSUM = "file://COPYING;md5=1ebbd3e34237af26da5dc08a4e440464"

# kaliru (branch rustify until it merges into main) with Rusticc's patches,
# as COSMOS builds Kalico with its own: files/kaliru, listed by
# rusticc-patches.inc (tools/kaliru-tree.sh / kaliru-export.sh)
SRC_URI = "git://github.com/Rusti3D/kaliru.git;protocol=https;branch=main"
SRCREV = "99812196fbded9e6c8f9250603f4f9944a08f3dc"
# git am: patch 0023 carries a binary file (the plugin mirror bundle)
PATCHTOOL = "git"
PV = "0.1.0+git"

require rusticc-patches.inc
require rusticc-crates.inc

inherit cargo

# tools/build_cc1.sh's build: no RustPython, the plugins on the
# image's libpython (dlopen'ed: no link dependency); non-PIE
CARGO_BUILD_FLAGS += "--no-default-features --features plugins --bin kaliru"
RUSTFLAGS:append = " -C relocation-model=static"
# (the image strips: an already stripped binary is a QA error)
export CARGO_PROFILE_RELEASE_STRIP = "false"

RDEPENDS:${PN} = "libpython3"

do_install:append() {
    mv ${D}${bindir}/kaliru ${D}${bindir}/rusticc
}
