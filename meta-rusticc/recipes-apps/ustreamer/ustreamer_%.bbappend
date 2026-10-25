# The camera's largest mode, 1280x720 (it offers up to 30 fps), at 15 fps
# in place of COSMOS's 864x480 at 10. The camera encodes the MJPEG itself
# (-c HW), so this costs ustreamer no encoding.
do_install:append() {
    sed -i -e 's/-r 864x480/-r 1280x720/' -e 's/ -f 10 / -f 15 /' ${D}${sysconfdir}/init.d/ustreamer
}
