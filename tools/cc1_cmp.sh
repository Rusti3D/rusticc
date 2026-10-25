#!/bin/bash
# Rusticc before it goes on the printer: the user's CC1 config
# (Originals_Base/addons/cc1_config: AFC, AFC_ACE, knock) in
# batch mode against the CC1's own MCU dictionaries (dicts/), with the
# COSMOS reference (ref_setup.sh) and with Rusticc, diffed like case_cmp.sh.
# The config is staged in ~/rk/cc1_stage (/etc/klipper paths point there),
# fresh for each side; the addons go into the reference's klippy for the run.
# usage: [CANVAS=1] cc1_cmp.sh [extra gcode file]
# CANVAS=1: COSMOS's stock config with the Elegoo Canvas (AFC_canvas) instead
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd)
# (in the kaliru tree with the Rusticc patches: tools/kaliru-tree.sh)
cd "${KALIRU:-$HERE/work/kaliru}"
ADDONS=${ADDONS:-$(realpath "$HERE/../Originals_Base/addons")}
REF=~/rk/cosmos_ref
STAGE=~/rk/cc1_stage
cp "$HERE"/dicts/*.dict /ci_build/dict/
installed=()
for f in "$ADDONS"/afc_extras/*.py; do cp "$f" $REF/klippy/extras/; installed+=("$REF/klippy/extras/$(basename "$f")"); done
for f in AFC_ACE knock; do cp -r "$ADDONS/plugins/$f" $REF/klippy/plugins/; installed+=("$REF/klippy/plugins/$f"); done
trap 'rm -rf "${installed[@]}"' EXIT
stage() {
    rm -rf $STAGE
    mkdir -p $STAGE/gcodes
    cp -r "$ADDONS/cc1_config/config" $STAGE/config
    ln -s $REF/klippy/plugins $STAGE/plugins
    grep -rl /etc/klipper $STAGE/config | xargs -r sed -i "s#/etc/klipper#$STAGE#g"
    # batch mode treats a non-critical MCU as absent; on the printer the bed
    # is there, so it is a normal MCU here
    sed -i '/^is_non_critical: true/d' $STAGE/config/klipper-readonly/machine.cfg
    # gamepad_jog was a throwaway test addon (the user's word): left out
    awk '/^\[/ { skip = ($0 == "[gamepad_jog]" || $0 ~ /^\[gcode_macro GAMEPAD_(ON|OFF)\]$/) } !skip' \
        $STAGE/config/printer.cfg > $STAGE/printer.tmp && mv $STAGE/printer.tmp $STAGE/config/printer.cfg
    sed -i "s#/etc/klipper#$STAGE#g" $REF/klippy/plugins/AFC_ACE/config/*.cfg
    dicts="cc1_dsp.dict bed=cc1_bed.dict hotend=cc1_toolhead.dict"
    if [ -n "$CANVAS" ]; then
        # COSMOS's stock Canvas setup instead of the user's printer.cfg:
        # elegoo_canvas in cosmos.conf makes build-klipper-var-config add
        # the include to zextras.cfg; OpenRFID from the local tree
        echo "[include klipper-readonly/*.cfg]" > $STAGE/config/printer.cfg
        echo "[include ../extras-readonly/canvas.cfg]" >> $STAGE/config/klipper-readonly/zextras.cfg
        sed -i "/^\[canvas_rfid CANVAS_1\]/a openrfid_path: $HOME/rk/openrfid/src" $STAGE/config/extras-readonly/canvas.cfg
        dicts="$dicts canvas=cc1_canvas.dict"
    fi
    {
        echo "CONFIG config/printer.cfg"
        echo "DICTIONARY $dicts"
        echo "G4 P1000"
        if [ -n "$EXTRA" ]; then cat "$EXTRA"; fi
    } > $STAGE/cc1.test
}
EXTRA=${1:+$(realpath "$1")}
rm -rf ~/rk/cc1_py ~/rk/cc1_rs
stage
python3 tools/refrun.py --out ~/rk/cc1_py --cwd $REF --klippy "$HOME/rk/venv315/bin/python -m klippy" $STAGE/cc1.test < /dev/null | tail -1
stage
KALIRU_KLIPPY_DIR=$REF/klippy \
KALIRU_LIBPYTHON=${KALIRU_LIBPYTHON:-$HOME/.local/share/uv/python/cpython-3.15-linux-x86_64-gnu/lib/libpython3.15.so.1.0} \
PYTHONPATH=$HOME/rk/venv315/lib/python3.15/site-packages \
python3 tools/refrun.py --out ~/rk/cc1_rs --klippy "${KALIRU_BIN:-$HOME/rk/target-rusticc/release/kaliru}" $STAGE/cc1.test < /dev/null | tail -1
python3 tools/refdiff.py ~/rk/cc1_py ~/rk/cc1_rs
