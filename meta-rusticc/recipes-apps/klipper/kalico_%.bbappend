# Rusticc's klippy in place of COSMOS's: the same configs, the same python
# tree (/usr/share/klipper/klippy: the python plugins, AFC, load from it;
# .version and APP_NAME as COSMOS sets them), the same service name
# (klipper), started with Rusticc instead of python3 klippy.py
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
RDEPENDS:${PN} += "rusticc"
