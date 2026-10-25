#!/bin/sh
# A/B measurement of klippy builds on the CC1, one after another, each
# idle-measured the same way (measure.sh, memmap.sh) after SETTLE seconds:
#   ab.sh OUT  NAME:BINARY:ENV  NAME:BINARY:ENV ...
# BINARY "stock" runs COSMOS's klippy (init script); ENV is extra
# environment (a=b,c=d) for rusticc-run.sh. COSMOS's klippy is running again
# at the end.
OUT=$1; shift
D=/user-resource/rusticc
SETTLE=${SETTLE:-240}
: > $OUT
stop_all() {
    /etc/init.d/klipper stop > /dev/null 2>&1
    kill $(pidof rusticc) 2> /dev/null
    sleep 3
}
for v in "$@"; do
    name=${v%%:*}; rest=${v#*:}; bin=${rest%%:*}; env=${rest#*:}
    stop_all
    if [ "$bin" = stock ]; then
        /etc/init.d/klipper start > /dev/null 2>&1
        sleep $SETTLE
        pid=$(cat /var/run/klipper.pid)
    else
        cp "$bin" $D/rusticc
        ( export $(echo "$env" | tr ',' ' '); sh $D/rusticc-run.sh > $D/run_$name.out 2>&1 ) &
        sleep $SETTLE
        pid=$(pidof rusticc)
    fi
    {
        echo "=== $name ($bin $env)"
        python3 $D/kcmd.py info | grep '"state"'
        sh $D/measure.sh $pid 120
        sh $D/memmap.sh $pid
    } >> $OUT 2>&1
done
stop_all
/etc/init.d/klipper start > /dev/null 2>&1
echo "=== done" >> $OUT
