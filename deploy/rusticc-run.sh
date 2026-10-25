#!/bin/sh
# Runs Rusticc on the CC1 in place of COSMOS's klippy, with the same
# arguments and environment as /etc/init.d/klipper. COSMOS's klippy must be
# stopped first (/etc/init.d/klipper stop); the way back is
# /etc/init.d/klipper start. Rusticc lives in /user-resource/rusticc (the
# root filesystem is read-only); the python plugins (AFC in klippy/extras,
# /etc/klipper/plugins) are read from COSMOS's klippy directory.
export TMPDIR="/user-resource/.tmp"
# the plugins' CPython with COSMOS's interpreter options (-X lazy_imports=all
# -X no_debug_ranges in its init script): modules load on first use, code
# objects carry no column tables
export PYTHON_LAZY_IMPORTS=all
export PYTHONNODEBUGRANGES=1
# glibc returns freed heap to the system sooner (measured on the CC1: -0.6 MB
# anonymous memory idle, no cpu change; deploy/ab.sh)
export GLIBC_TUNABLES=glibc.malloc.trim_threshold=131072:glibc.malloc.top_pad=0
# 120 s after start, resident code drops to the working set (startup code and
# read-around stay in the page cache only; measured on the CC1: binary 6.5 ->
# 5.0 MB, libpython 5.1 -> 4.2 MB resident)
export KALIRU_TRIM_TEXT=120
export KALIRU_KLIPPY_DIR="/usr/share/klipper/klippy"
export KALIRU_LIBPYTHON="/usr/lib/libpython3.15.so.1.0"
exec /user-resource/rusticc/rusticc /etc/klipper/config/printer.cfg \
    -l /board-resource/klippy.log -a /run/klippy.sock "$@"
