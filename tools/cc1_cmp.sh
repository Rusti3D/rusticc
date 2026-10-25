#!/bin/bash
# Rusticc before it goes on the printer: the user's CC1 config
# (work/cc1_live from tools/cc1_pull.sh, else Originals_Base/addons/cc1_config:
# AFC, AFC_ACE) in
# batch mode against the CC1's own MCU dictionaries (dicts/), with the
# COSMOS reference (ref_setup.sh) and with Rusticc, diffed like case_cmp.sh.
# The config is staged in ~/rk/cc1_stage (/etc/klipper paths point there),
# fresh for each side; the addons go into the reference's klippy for the run.
# usage: [CANVAS=1] [ACE=slots] cc1_cmp.sh [extra gcode file]
# CANVAS=1: COSMOS's stock config with the Elegoo Canvas (AFC_canvas) instead
# ACE=ready:PLA,empty,... [ACE_EVENTS=secs:slot:state,...]: a fake ACE Pro (tools/fake_ace.py) on the unit's
# serial, a fresh one for each side; ACE_OFFLINE_LOADS=1 lets loads run
# offline (see below)
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd)
# (in the kaliru tree with the Rusticc patches: tools/kaliru-tree.sh)
cd "${KALIRU:-$HERE/work/kaliru}"
ADDONS=${ADDONS:-$(realpath "$HERE/../Originals_Base/addons")}
LIVE=$HERE/work/cc1_live
if [ -d "$LIVE" ]; then CONFIG=$LIVE/config; PLUGINS=$LIVE/plugins; else CONFIG=$ADDONS/cc1_config/config; PLUGINS=$ADDONS/plugins; fi
REF=~/rk/cosmos_ref
STAGE=~/rk/cc1_stage
cp "$HERE"/dicts/*.dict /ci_build/dict/
installed=()
for f in "$ADDONS"/afc_extras/*.py; do cp "$f" $REF/klippy/extras/; installed+=("$REF/klippy/extras/$(basename "$f")"); done
cp -r "$PLUGINS/AFC_ACE" $REF/klippy/plugins/; installed+=("$REF/klippy/plugins/AFC_ACE")
fake=
trap 'rm -rf "${installed[@]}"; [ -n "$fake" ] && kill $fake' EXIT
stage() {
    rm -rf $STAGE
    mkdir -p $STAGE/gcodes
    cp -r "$CONFIG" $STAGE/config
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
        # a fresh install's AFC state, not the user's ACE lanes
        echo "{}" > $STAGE/config/AFC.var.unit
    fi
    if [ -n "$ACE" ]; then
        [ -n "$fake" ] && kill $fake && wait $fake 2>/dev/null
        python3 "$HERE/tools/fake_ace.py" $STAGE/ace_tty --slots "$ACE" --events "$ACE_EVENTS" --speedup ${ACE_SPEEDUP:-20} & fake=$!
        sed -i "s#^serial: /dev/serial/by-path/.*#serial: $STAGE/ace_tty#" $STAGE/config/printer.cfg
        # ACE_FRESH=1: a fresh install's AFC state, not the printer's lanes
        if [ -n "$ACE_FRESH" ]; then echo "{}" > $STAGE/config/AFC.var.unit; fi
        if [ -n "$ACE_OFFLINE_LOADS" ]; then
            # batch mode reads no temperatures or sensors: loads skip the
            # heat-up (0 C materials, cold extrusion allowed) and feed blind
            sed -i "/^pin_tool_start:/d" $REF/klippy/plugins/AFC_ACE/config/cc1-head.cfg
            printf '
[AFC]
default_material_temps: default:0, PLA:0, PETG:0
[extruder]
min_extrude_temp: 0
' >> $STAGE/config/printer.cfg
        fi
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
python3 tools/refrun.py --timeout ${TIMEOUT:-600} --out ~/rk/cc1_py --cwd $REF --klippy "$HOME/rk/venv315/bin/python -m klippy" $STAGE/cc1.test < /dev/null | tail -1
stage
# RS_PY_AFC=1: Rusticc runs the python AFC (its escape hatch; the reference
# has no such option): the plugin layer against the reference
# (its own included file: printer.cfg ends in the SAVE_CONFIG block)
if [ -n "$RS_PY_AFC" ]; then printf '[danger_options]\nuse_python_modules: AFC\n' > $STAGE/config/klipper-readonly/zz-rusticc-python-afc.cfg; fi
KALIRU_KLIPPY_DIR=$REF/klippy \
KALIRU_LIBPYTHON=${KALIRU_LIBPYTHON:-$HOME/.local/share/uv/python/cpython-3.15-linux-x86_64-gnu/lib/libpython3.15.so.1.0} \
PYTHONPATH=$HOME/rk/venv315/lib/python3.15/site-packages \
python3 tools/refrun.py --timeout ${TIMEOUT:-600} --out ~/rk/cc1_rs --klippy "${KALIRU_BIN:-$HOME/rk/target-rusticc/release/kaliru}" $STAGE/cc1.test < /dev/null | tail -1
python3 tools/refdiff.py ~/rk/cc1_py ~/rk/cc1_rs
