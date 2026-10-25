# The update entry build-klipper-var-config writes for Moonraker's update
# manager ([update_manager cosmos] type: swupdate) fetches Rusticc's images
# (github.com/Rusti3D/rusticc), as check-update and update-cosmos do; the
# image file name stays COSMOS's cosmos-<machine>.swu
do_install:append() {
    sed -i -e 's#OpenCentauri/cosmos#Rusti3D/rusticc#g' ${D}${bindir}/build-klipper-var-config
}

# The settings file keeps its name (cosmos.conf: tools and the user's edits
# use it); its header names Rusticc
do_install:append() {
    for f in ${D}${sysconfdir}/klipper/config/cosmos.conf ${D}${datadir}/config-manager/default-machine.conf; do
        sed -i -e 's/^# OpenCentauri COSMOS settings\./# Rusticc settings (the COSMOS settings file)./' \
            -e 's/the COSMOS updater/the Rusticc updater/' $f
    done
}
