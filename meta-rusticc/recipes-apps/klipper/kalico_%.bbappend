# Rusticc's klippy in place of COSMOS's: the same configs, the same python
# tree (/usr/share/klipper/klippy: the python plugins, AFC, load from it;
# .version and APP_NAME as COSMOS sets them), the same service name
# (klipper), started with Rusticc instead of python3 klippy.py
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
RDEPENDS:${PN} += "rusticc"

# The prompts COSMOS's macros show by name: Rusticc's. (Macro names such as
# _COSMOS_SETTINGS / UPDATE_COSMOS and the "COSMOS OrcaSlicer profile" a
# print needs stay: configs and slicer profiles call them.)
do_install:append() {
    sed -i -e 's/Welcome to COSMOS!/Welcome to Rusticc!/' \
        ${D}${sysconfdir}/klipper/config/klipper-readonly/calibration.cfg
    sed -i -e 's/while COSMOS is updated/while Rusticc is updated/' \
        ${D}${sysconfdir}/klipper/config/klipper-readonly/shell.cfg
}

# moonraker-timelapse c7fff11's macros (klipper_macro/timelapse.cfg) for
# Moonruster's timelapse component; klipper-readonly/*.cfg is included by
# printer.cfg. A frame per layer needs TIMELAPSE_TAKE_FRAME in the slicer's
# layer-change G-code.
SRC_URI += "file://timelapse.cfg"
do_install:append() {
    install -m 0644 ${UNPACKDIR}/timelapse.cfg ${D}${sysconfdir}/klipper/config/klipper-readonly/
}
