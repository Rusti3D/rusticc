#!/bin/bash
# Builds the Rusticc parity reference in WSL: ~/rk/cosmos_ref = Kalico
# 5b59427 + COSMOS's patches (make_ref.sh) + kaliru's serialqueue trace
# (tools/ref_trace.patch), with its c_helper built for ~/rk/venv315.
# Safe to rerun (rebuilds from scratch).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
KALIRU=${KALIRU:-$HERE/../work/kaliru}
REF=~/rk/cosmos_ref
rm -rf "$REF"
bash "$HERE/make_ref.sh" "$REF"
cd "$REF"
patch -p1 -s --no-backup-if-mismatch < "$KALIRU/tools/ref_trace.patch"
# as COSMOS installs it (kalico_2026.02.00.bb do_install): no git
# repository, APP_NAME = the distro name, klippy/.version, compiled .pyc
sed -i 's/APP_NAME = "Kalico"/APP_NAME = "Rusticc"/' klippy/__init__.py
echo "Release - test" > klippy/.version
# c_helper.so without FMA contraction, as kaliru's reference (tools/build_ref_chelper.py)
~/rk/venv315/bin/python "$KALIRU/tools/build_ref_chelper.py"
~/rk/venv315/bin/python -c "import klippy.chelper as c; c.get_ffi(); print('c_helper ok')"
~/rk/venv315/bin/python -m compileall -q --invalidation-mode checked-hash -d /usr/share/klipper/klippy klippy > /dev/null 2>&1 || true
# the CC1 bed MCU's data dictionary (COSMOS config.bed: hx711s), for the
# cases/ that use it
P="/mnt/d/Carbon Centauri/cosmos/meta-opencentauri/recipes-apps/klipper/files"
FW=$(mktemp -d)
cp -r "$REF/." "$FW"
cp "$P/centauri-carbon-1/config.bed" "$FW/.config"
make -C "$FW" olddefconfig > /dev/null
make -C "$FW" -j8 > /dev/null
cp "$FW/out/klipper.dict" /ci_build/dict/cc1_bed.dict
rm -rf "$FW"
echo "reference ready"
