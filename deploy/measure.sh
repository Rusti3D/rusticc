#!/bin/sh
# Memory and CPU of the running klippy (COSMOS's python or Rusticc), read
# from /proc only. usage: measure.sh PID [SECONDS]
# Memory: RSS split anon/file, swapped out (zram), PSS / private from
# smaps_rollup. CPU: utime+stime ticks over SECONDS while idle, as % of one core.
PID=$1
SECS=${2:-60}
HZ=100
ticks() { awk '{print $14 + $15}' /proc/$PID/stat; }
echo "pid $PID: $(tr '\0' ' ' < /proc/$PID/cmdline | cut -c1-100)"
grep -E "^(VmRSS|RssAnon|RssFile|VmSwap|Threads)" /proc/$PID/status
grep -E "^(Pss|Pss_Anon|Pss_File|Private_Clean|Private_Dirty|Swap):" /proc/$PID/smaps_rollup
for t in /proc/$PID/task/*; do echo "$(basename $t) $(cat $t/comm) $(awk '{print $14 + $15}' $t/stat)"; done > /tmp/measure_a
t0=$(ticks); sleep $SECS; t1=$(ticks)
for t in /proc/$PID/task/*; do echo "$(basename $t) $(awk '{print $14 + $15}' $t/stat)"; done > /tmp/measure_b
echo "threads (ticks in ${SECS}s):"
awk 'NR==FNR{b[$1]=$2; next} {d=b[$1]-$3; if (d > 0) printf "  %-16s %d\n", $2, d}' /tmp/measure_b /tmp/measure_a
rm -f /tmp/measure_a /tmp/measure_b
echo "cpu: $((t1 - t0)) ticks in ${SECS}s = $(awk -v d=$((t1 - t0)) -v s=$SECS -v hz=$HZ 'BEGIN{printf "%.2f", 100*d/hz/s}')% of one core"
echo "total cpu since start: $(awk -v hz=$HZ '{printf "%.1f", ($14+$15)/hz}' /proc/$PID/stat)s, up $(awk -v hz=$HZ -v up=$(cut -d' ' -f1 /proc/uptime) '{printf "%.0f", up - $22/hz}' /proc/$PID/stat)s"
grep -E "^(MemAvailable|SwapFree)" /proc/meminfo
