#!/bin/sh
# Switch the CC1's klippy between COSMOS's (stock) and Rusticc, by hand. The
# root filesystem is read-only, so nothing is changed for the next boot: a
# reboot always starts stock.
#   rusticc-switch.sh rusticc   stop stock klippy, start Rusticc
#   rusticc-switch.sh stock     stop Rusticc, start stock klippy
#   rusticc-switch.sh status    which one runs, and its state
D=/user-resource/rusticc
PID=/var/run/rusticc.pid
state() {
    python3 $D/kcmd.py info 2>/dev/null | grep -E '"(app|state)"' | tr -d ' ,'
}
case "$1" in
    rusticc)
        /etc/init.d/klipper stop
        start-stop-daemon -K -q -p $PID 2> /dev/null
        sleep 2
        start-stop-daemon -S -b -m -p $PID -x /bin/sh -- $D/rusticc-run.sh
        echo "Rusticc started (log: /board-resource/klippy.log)"
        ;;
    stock)
        start-stop-daemon -K -q -p $PID 2> /dev/null
        rm -f $PID
        sleep 2
        /etc/init.d/klipper start
        ;;
    status)
        if [ -f $PID ] && kill -0 $(cat $PID) 2> /dev/null; then
            echo "running: Rusticc (pid $(cat $PID))"
        elif pidof python3 > /dev/null && ps w | grep -q "[k]lippy.py"; then
            echo "running: stock klippy"
        else
            echo "running: neither"
        fi
        state
        ;;
    *)
        echo "usage: $0 rusticc|stock|status"
        exit 1
        ;;
esac
