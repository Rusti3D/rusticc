#!/bin/bash
# Builds the Rusticc parity reference: Kalico 5b59427 (kaliru's base) with
# COSMOS's klipper patch set and extras applied in the recipe's order
# (meta-opencentauri/recipes-apps/klipper/kalico_2026.02.00.inc SRC_URI).
# See ../docs/cosmos_audit.md for why each one is (or is not) applied.
#
# usage: make_ref.sh DEST   (run in WSL; needs ~/rk/kalico)
set -e
DEST=${1:?usage: make_ref.sh DEST}
P="/mnt/d/Carbon Centauri/cosmos/meta-opencentauri/recipes-apps/klipper/files"
R=$(cd "$(dirname "$0")/../reference-patches" && pwd)
mkdir -p "$DEST"
git -C ~/rk/kalico archive 5b59427 | tar -x -C "$DEST"
cd "$DEST"
for n in 0001-remove-save-config-subfile-check \
         0002-reduce-calibration-difference-tolerance \
         0001-Reduce-log-rotate-threshold \
         0001-implement-pulldown-resistor-in-thermistor-calc \
         0001-probe-home-z-includes-z-offset \
         0001-force-specific-input-shaper \
         0003-drv8833-motor-control; do
    patch -p1 -s --no-backup-if-mismatch < "$P/$n.patch"
done
# rebased: the COSMOS file does not apply to 5b59427
patch -p1 -s --no-backup-if-mismatch < "$R/0004-allow-config-exclude.patch"
# 0001-Increase-max-velocity-in-resonance-tester: already in 5b59427 (8497e5ad)
for n in 0005-stm32-serial-rs485-de-pin \
         0006-Add-support-for-hifi4 \
         0007-Add-HX711s-load-cell-probe-driver; do
    patch -p1 -s --no-backup-if-mismatch < "$P/$n.patch"
done
cp "$P/canvas_rfid.py" "$P/canvas_filament_sensor.py" klippy/extras/
echo "reference tree in $DEST"
