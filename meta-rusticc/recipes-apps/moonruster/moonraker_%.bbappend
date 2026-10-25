# Rusticc's Moonraker in place of COSMOS's: the same configs, the same python
# tree (/usr/share/moonraker: python components load from it), the same
# service name (moonraker), started with Moonruster instead of python3
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
RDEPENDS:${PN} += "moonruster"

# The [timelapse] section, through moonraker.conf's
# [include moonraker-readonly/*.conf]
SRC_URI += "file://timelapse.conf"
do_install:append() {
    install -m 0644 ${UNPACKDIR}/timelapse.conf ${D}${sysconfdir}/klipper/config/moonraker-readonly/
}
FILES:${PN} += "${sysconfdir}/klipper/config/moonraker-readonly/timelapse.conf"
