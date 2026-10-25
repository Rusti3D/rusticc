#!/bin/bash
# Builds Rusticc for the CC1 (armv7, glibc): kaliru without the embedded
# RustPython; python macros and plugins run on the printer's CPython 3.15.
# Output: ~/rk/target-rusticc-arm/armv7-unknown-linux-gnueabihf/release/kaliru
# (deployed as /user-resource/rusticc/rusticc, deploy/).
HERE=$(cd "$(dirname "$0")/.." && pwd)
# (in the kaliru tree with the Rusticc patches: tools/kaliru-tree.sh)
cd "${KALIRU:-$HERE/work/kaliru}"
# non-PIE: no load-time relocation of the binary's data (dlopen of
# libpython still works)
RUSTFLAGS="${RUSTFLAGS:+$RUSTFLAGS }-C relocation-model=static" CARGO_TARGET_DIR=${CARGO_TARGET_DIR:-$HOME/rk/target-rusticc-arm} \
    bash tools/build_armv7.sh --no-default-features --features plugins "$@"
