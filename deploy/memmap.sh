#!/bin/sh
# Memory of a process by mapping group (from /proc/PID/smaps): the binary,
# libpython + python extension modules, other shared libraries, heap
# (brk + anonymous mmaps), stacks. Columns in kB: Rss, Anonymous, Swap.
# usage: memmap.sh PID
awk '
/^[0-9a-f]+-[0-9a-f]+ / {
    path = (NF >= 6) ? $6 : "[anon]"
    if (path ~ /libpython|python3\.[0-9]+\//) g = "python (libpython + modules)"
    else if (path ~ /\.so/) g = "other shared libs"
    else if (path == "[heap]" || path == "[anon]") g = "heap (brk + anon mmap)"
    else if (path ~ /^\[stack/) g = "stack"
    else if (path ~ /^\[/) g = path
    else g = "binary: " path
    next
}
/^Rss:/ { rss[g] += $2 }
/^Anonymous:/ { anon[g] += $2 }
/^Swap:/ { swap[g] += $2 }
END {
    printf "%-60s %8s %8s %8s\n", "group", "Rss", "Anon", "Swap"
    for (k in rss) { printf "%-60s %8d %8d %8d\n", k, rss[k], anon[k], swap[k]; tr += rss[k]; ta += anon[k]; ts += swap[k] }
    printf "%-60s %8d %8d %8d\n", "TOTAL", tr, ta, ts
}' /proc/$1/smaps
