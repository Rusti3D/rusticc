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

# No Moonraker python stack (user: Moonraker "shouldn't ship with rusticc at
# all"): Moonruster replaces it, and a python Moonraker component it loads
# gets the moonraker package from a mirror built into Moonruster. Kept: the
# drop-in components directory, and the default asvc moonraker-init-d
# compares the overlay's with. ([notifier] needs apprise and third-party
# components their own packages: not shipped.)
RDEPENDS:${PN}:remove = " \
    python3 python3-tornado python3-pyserial-asyncio python3-pillow python3-streaming-form-data \
    python3-distro python3-inotify-simple python3-libnacl python3-paho-mqtt python3-zeroconf \
    python3-preprocess-cancellation python3-dbus-fast python3-apprise python3-ldap3 \
    python3-periphery python3-importlib-metadata python3-zipp python3-smart-open python3-msgspec \
    python3-uvloop python3-aiofiles python3-jinja2 python3-pyserial \
"
do_install:append() {
    cp ${D}${datadir}/moonraker/moonraker/assets/default_allowed_services ${WORKDIR}/asvc
    rm -rf ${D}${datadir}/moonraker
    install -d ${D}${datadir}/moonraker/moonraker/assets ${D}${datadir}/moonraker/moonraker/components
    install -m 0644 ${WORKDIR}/asvc ${D}${datadir}/moonraker/moonraker/assets/default_allowed_services
}
