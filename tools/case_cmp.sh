#!/bin/bash
# Rusticc parity: runs test cases with the COSMOS reference (ref_setup.sh)
# and with kaliru's Rusticc build, then diffs them like tools/case_cmp.sh.
# usage: case_cmp.sh <test files...>
HERE=$(cd "$(dirname "$0")/.." && pwd)
# (in the kaliru tree with the Rusticc patches: tools/kaliru-tree.sh)
cd "${KALIRU:-$HERE/work/kaliru}"
tests=()
for t in "$@"; do tests+=("$(realpath "$t")"); done
rm -rf ~/rk/rusticc_py ~/rk/rusticc_rs
python3 tools/refrun.py --out ~/rk/rusticc_py --cwd ~/rk/cosmos_ref --klippy "$HOME/rk/venv315/bin/python -m klippy" "${tests[@]}" < /dev/null | tail -1
# kaliru reads klippy/.version and runs git where the reference's klippy is
KALIRU_KLIPPY_DIR=~/rk/cosmos_ref/klippy python3 tools/refrun.py --out ~/rk/rusticc_rs --klippy "${KALIRU_BIN:-$HOME/rk/target-rusticc/release/kaliru}" "${tests[@]}" < /dev/null | tail -1
python3 tools/refdiff.py ~/rk/rusticc_py ~/rk/rusticc_rs
