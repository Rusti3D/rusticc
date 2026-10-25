# Rusticc ships Moonruster only: the moonraker package keeps COSMOS's service
# name (moonraker: Mainsail, moonraker.asvc and the update scripts use it),
# configs and links, but no Moonraker python tree and none of the python
# packages only Moonraker uses. Kalico's own python dependencies come from
# kalico. The service runs Moonruster (moonraker-init-d).
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
RDEPENDS:${PN} = "moonruster curl kalico"

# Timelapse is disabled until it is finished (docs/TIMELAPSE.md): no
# [timelapse] section (files/timelapse.conf), so Moonruster's component
# (patch 0005) does not load.

do_install() {
    install -d ${D}${sysconfdir}/klipper/config/moonraker-readonly
    install -m 0644 ${UNPACKDIR}/moonraker.conf ${D}${sysconfdir}/klipper/config/
    install -m 0644 ${UNPACKDIR}/moonraker-readonly.conf ${D}${sysconfdir}/klipper/config/moonraker-readonly/moonraker.conf
    # Web UI addons (Moonruster patch 0006): the image's panel extender and
    # its panels, then writable storage for runtime-installed addons
    sed -i 's|^web_client: .*|&\naddons_path:\n    /var/www/addons\n    /user-resource/webui-addons|' \
        ${D}${sysconfdir}/klipper/config/moonraker-readonly/moonraker.conf
    grep -q '^addons_path:' ${D}${sysconfdir}/klipper/config/moonraker-readonly/moonraker.conf
    install -m 0644 ${UNPACKDIR}/moonraker.asvc ${D}${sysconfdir}/klipper/
    ln -sf /user-resource/gcodes ${D}${sysconfdir}/klipper/gcodes
    ln -sf /board-resource ${D}${sysconfdir}/klipper/logs
    install -d ${D}${sysconfdir}/init.d
    install -m 0755 ${UNPACKDIR}/moonraker-init-d ${D}${sysconfdir}/init.d/moonraker
}

FILES:${PN}:remove = "${datadir}/moonraker"

