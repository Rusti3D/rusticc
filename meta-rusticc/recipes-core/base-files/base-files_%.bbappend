# Rusticc's login banner
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI += "file://motd-rusticc"

do_install:append() {
    install -m 0644 ${UNPACKDIR}/motd-rusticc ${D}${sysconfdir}/motd
}
