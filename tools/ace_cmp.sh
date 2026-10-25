#!/bin/bash
# Native AFC_ACE parity on the user's CC1 config: each scenario against a
# fake ACE Pro (tools/fake_ace.py), the reference and Rusticc each with a
# fresh one. Same env as cc1_cmp.sh.
HERE=$(cd "$(dirname "$0")/.." && pwd)
C=$HERE/cases
run() { echo "== $1"; local case=$2; shift 2; env "$@" bash "$HERE/tools/cc1_cmp.sh" "$C/$case.gcode" 2>&1 | tail -1; }
SLOTS=ready:PLA,empty,ready:PETG,empty
run "status, dryer" cc1_ace ACE=$SLOTS
run "lane moves, reset, stop, dryer heater" cc1_ace_moves ACE=$SLOTS
run "loads, unloads, tool changes (offline)" cc1_ace_load ACE=$SLOTS ACE_OFFLINE_LOADS=1
run "spool in / out, bypass" cc1_ace_events ACE=$SLOTS ACE_FRESH=1 ACE_OFFLINE_LOADS=1 ACE_SPEEDUP=1 ACE_EVENTS=1:1:ready:PETG,4:0:empty
