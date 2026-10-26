# Rusticc's boot splash (rusticc_1.png, made by
# branding/make_assets.py); COSMOS's colours. No bar: the boot progress
# lights the logo's stripes (0001-rusticc-progress-fills-the-logo-stripes:
# rusticc_1_stripes.png over rusticc_1_stripes_dim.png at
# psplash-rusticc-stripes.h's position)
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI += " \
    file://0001-rusticc-progress-fills-the-logo-stripes.patch \
    file://rusticc_1_stripes.png \
    file://rusticc_1_stripes_dim.png \
    file://psplash-rusticc-stripes.h;subdir=${BPN}-${PV} \
"
SPLASH_IMAGES = " \
    file://rusticc_1.png;outsuffix=default \
"

do_compile:prepend() {
    import subprocess
    import shutil
    workdir = d.getVar('UNPACKDIR')
    convertscript = "%s/make-image-header.sh" % d.getVar('S')
    for png, name, header in (("rusticc_1_stripes.png", "STRIPES", "psplash-stripes-img.h"),
                              ("rusticc_1_stripes_dim.png", "STRIPES_DIM", "psplash-stripes-dim-img.h")):
        if subprocess.call([convertscript, os.path.join(workdir, png), name], cwd=workdir):
            bb.fatal("Error converting %s" % png)
        shutil.copyfile(os.path.join(workdir, png.replace(".png", "-img.h")), "%s/%s" % (d.getVar('B'), header))
}
