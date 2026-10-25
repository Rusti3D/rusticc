# Rusticc ships GrumpyScreen only: a printer set to a screen UI the image
# doesn't have (atomscreen) starts GrumpyScreen
do_install:append() {
    sed -i 's|^        if \[ -x "/etc/init.d/\$GUI" \]; then|        [ -x "/etc/init.d/$GUI" ] \|\| GUI=grumpyscreen\n&|' ${D}${sysconfdir}/init.d/gui-switcher
}
