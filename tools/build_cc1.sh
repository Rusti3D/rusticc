#!/bin/bash
# Builds Rusticc for the CC1 (armv7, glibc): the rusticc crate of the patched
# kaliru tree, kaliru with Rust-AFC built in, without the embedded RustPython;
# python macros and plugins run on the printer's CPython 3.15.
# Output: ~/rk/target-rusticc-arm/armv7-unknown-linux-gnueabihf/release/rusticc
# (deployed as /usr/bin/rusticc, work/repack/repack.sh).
HERE=$(cd "$(dirname "$0")/.." && pwd)
# (in the kaliru tree with the Rusticc patches: tools/kaliru-tree.sh)
cd "${KALIRU:-$HERE/work/kaliru}"
# non-PIE: no load-time relocation of the binary's data (dlopen of
# libpython still works); gcc's cross linker, as kaliru's
# tools/build_armv7.sh (zig's would change float results)
RUSTFLAGS="${RUSTFLAGS:+$RUSTFLAGS }-C relocation-model=static" \
CARGO_TARGET_ARMV7_UNKNOWN_LINUX_GNUEABIHF_LINKER=arm-linux-gnueabihf-gcc \
CARGO_TARGET_DIR=${CARGO_TARGET_DIR:-$HOME/rk/target-rusticc-arm} \
    ~/.cargo/bin/cargo build --release --target armv7-unknown-linux-gnueabihf \
    --manifest-path rusticc/Cargo.toml --bin rusticc "$@"
