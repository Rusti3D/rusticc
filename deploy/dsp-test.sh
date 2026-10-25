#!/bin/sh
# Load Rusticc's HiFi4 DSP firmware (the mainboard MCU) on the CC1 by hand,
# from /user-resource/rusticc, and back to COSMOS's. Nothing is changed for
# the next boot: the firmware path is a runtime setting, and a reboot
# always loads stock. Stopping the DSP runs COSMOS's init script, which
# drives the heaters, fans and stepper enables to their safe levels.
#   dsp-test.sh rusticc    stop klippy, load rusticc-dsp.elf, read its dictionary and trace
#   dsp-test.sh stock      load COSMOS's rproc-1700000.dsp-fw again, start stock klippy
#   dsp-test.sh status     the DSP's state, firmware and trace
D=/user-resource/rusticc
RP=/sys/class/remoteproc/remoteproc0
TRACE=/sys/kernel/debug/remoteproc/remoteproc0/trace0
trace() {
    mount | grep -q debugfs || mount -t debugfs none /sys/kernel/debug
    echo "--- trace:"; cat $TRACE 2> /dev/null; echo
}
case "$1" in
    rusticc)
        sh $D/rusticc-switch.sh stock > /dev/null 2>&1
        /etc/init.d/klipper stop
        /etc/init.d/klipper-firmware-dsp stop
        echo -n $D > /sys/module/firmware_class/parameters/path
        echo rusticc-dsp.elf > $RP/firmware
        echo start > $RP/state
        sleep 2
        echo "state: $(cat $RP/state) firmware: $(cat $RP/firmware)"
        trace
        python3 $D/mcu_identify.py /dev/ttyRPMSG0 > $D/dsp_dict.json && echo "dictionary: $D/dsp_dict.json"
        ;;
    stock)
        /etc/init.d/klipper-firmware-dsp stop
        echo -n "" > /sys/module/firmware_class/parameters/path
        echo rproc-1700000.dsp-fw > $RP/firmware
        /etc/init.d/klipper-firmware-dsp start
        sleep 2
        echo "state: $(cat $RP/state) firmware: $(cat $RP/firmware)"
        /etc/init.d/klipper start
        ;;
    status)
        echo "state: $(cat $RP/state) firmware: $(cat $RP/firmware) path: $(cat /sys/module/firmware_class/parameters/path)"
        trace
        ;;
    *)
        echo "usage: $0 rusticc|stock|status"
        exit 1
        ;;
esac
