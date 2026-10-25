#!/bin/bash
# Native AFC Canvas parity: cc1_canvas.gcode, cc1_canvas_moves.gcode, then each
# line of cc1_canvas_errors.txt as its own run. Same env as cc1_cmp.sh.
HERE=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
run() { echo "== $1"; CANVAS=1 bash "$HERE/tools/cc1_cmp.sh" "$2" 2>&1 | tail -1; }
run canvas "$HERE/cases/cc1_canvas.gcode"
run moves "$HERE/cases/cc1_canvas_moves.gcode"
grep -v '^#' "$HERE/cases/cc1_canvas_errors.txt" | while IFS= read -r c; do
    printf 'G4 P3000\nPREP\n%s\n' "$c" > "$tmp/one.gcode"
    run "$c" "$tmp/one.gcode"
done
