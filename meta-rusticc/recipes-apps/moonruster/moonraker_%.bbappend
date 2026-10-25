# Rusticc ships Moonruster only: the moonraker package keeps COSMOS's service
# name (moonraker: Mainsail, moonraker.asvc and the update scripts use it),
# configs and links, but no Moonraker python tree and none of the python
# packages only Moonraker uses. Kalico's own python dependencies come from
# kalico. The service runs Moonruster (moonraker-init-d).
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
RDEPENDS:${PN} = "moonruster curl kalico"

# The [timelapse] section, through moonraker.conf's
# [include moonraker-readonly/*.conf]
SRC_URI += "file://timelapse.conf"

do_install() {
    install -d ${D}${sysconfdir}/klipper/config/moonraker-readonly
    install -m 0644 ${UNPACKDIR}/moonraker.conf ${D}${sysconfdir}/klipper/config/
    install -m 0644 ${UNPACKDIR}/moonraker-readonly.conf ${D}${sysconfdir}/klipper/config/moonraker-readonly/moonraker.conf
    install -m 0644 ${UNPACKDIR}/timelapse.conf ${D}${sysconfdir}/klipper/config/moonraker-readonly/
    install -m 0644 ${UNPACKDIR}/moonraker.asvc ${D}${sysconfdir}/klipper/
    ln -sf /user-resource/gcodes ${D}${sysconfdir}/klipper/gcodes
    ln -sf /board-resource ${D}${sysconfdir}/klipper/logs
    install -d ${D}${sysconfdir}/init.d
    install -m 0755 ${UNPACKDIR}/moonraker-init-d ${D}${sysconfdir}/init.d/moonraker
}

FILES:${PN}:remove = "${datadir}/moonraker"
FILES:${PN} += "${sysconfdir}/klipper/config/moonraker-readonly/timelapse.conf"

