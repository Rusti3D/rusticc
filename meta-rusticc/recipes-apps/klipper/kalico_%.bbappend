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

    # Nozzle Z homing calibrates [load_cell_probe], not the endstop.
    sed -i \
        -e '/Z_OFFSET_APPLY_ENDSTOP is not supported when nozzle z homing is enabled\./c\    Z_OFFSET_APPLY_PROBE' \
        ${D}${sysconfdir}/klipper/config/klipper-readonly/shared-macros.cfg
}

# Timelapse is disabled until it is finished (docs/TIMELAPSE.md): its
# macros, files/timelapse.cfg, are not installed.

# klippy's python packages that kaliru replaces and no python plugin imports
# (its greenlets, msgspec and CAN tooling are Rust). Kept for python plugins:
# python3, numpy, pyserial, jinja2 + markupsafe, cffi + pycparser.
RDEPENDS:${PN}:remove = "python3-greenlet python3-msgspec python3-can"
