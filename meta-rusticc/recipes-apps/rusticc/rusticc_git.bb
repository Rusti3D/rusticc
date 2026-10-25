SUMMARY = "Rusticc klippy: Kalico with COSMOS's patches, in Rust, AFC built in"
DESCRIPTION = "kaliru (Kalico ported to Rust) with Rusticc's patches: COSMOS's klippy without the embedded RustPython; python plugins and macros run on the image's CPython."
HOMEPAGE = "https://github.com/Rusti3D/kaliru"
LICENSE = "GPL-3.0-only"
LIC_FILES_CHKSUM = "file://COPYING;md5=1ebbd3e34237af26da5dc08a4e440464"

# kaliru (branch rustify until it merges into main) with Rusticc's patches,
# as COSMOS builds Kalico with its own: files/kaliru, listed by
# rusticc-patches.inc (tools/kaliru-tree.sh / kaliru-export.sh)
SRC_URI = "git://github.com/Rusti3D/kaliru.git;protocol=https;branch=main \
           git://github.com/Rusti3D/Rust-AFC.git;protocol=https;branch=main;name=rust-afc;destsuffix=rust-afc \
"
SRCREV = "d0f37ad3c1592d798e327fa2b3fcea2cd580b148"
# Rust-AFC, the native AFC plugin the rusticc crate builds in (the rev its
# Cargo.toml names); cargo_common points the git dependency at this checkout
SRCREV_rust-afc = "3ea26b12f6d00b237d18aa1681735d227dd454ad"
SRCREV_FORMAT = "default_rust-afc"
# git am: patch 0023 carries a binary file (the plugin mirror bundle)
PATCHTOOL = "git"
PV = "0.1.0+git"

require rusticc-patches.inc
require rusticc-crates.inc

inherit cargo

# tools/build_cc1.sh's build: the rusticc crate (kaliru, no RustPython, the
# python plugins on the image's libpython, dlopen'ed: no link dependency;
# Rust-AFC built in); non-PIE. (Not yet built with Yocto: Rusticc images are
# repacked, docs/RELEASE.md.)
CARGO_SRC_DIR = "rusticc"
CARGO_BUILD_FLAGS += "--bin rusticc"
RUSTFLAGS:append = " -C relocation-model=static"
# (the image strips: an already stripped binary is a QA error)
export CARGO_PROFILE_RELEASE_STRIP = "false"

RDEPENDS:${PN} = "libpython3"
