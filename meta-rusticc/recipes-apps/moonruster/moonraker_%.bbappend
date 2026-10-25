# Rusticc's Moonraker in place of COSMOS's: the same configs, the same python
# tree (/usr/share/moonraker: python components load from it), the same
# service name (moonraker), started with Moonruster instead of python3
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
RDEPENDS:${PN} += "moonruster"
