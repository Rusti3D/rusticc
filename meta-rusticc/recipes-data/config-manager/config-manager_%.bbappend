# The update entry build-klipper-var-config writes for Moonraker's update
# manager ([update_manager cosmos] type: swupdate) fetches Rusticc's images
# (github.com/Rusti3D/rusticc), as check-update and update-cosmos do; the
# image file name stays COSMOS's cosmos-<machine>.swu
do_install:append() {
    sed -i -e 's#OpenCentauri/cosmos#Rusti3D/rusticc#g' ${D}${bindir}/build-klipper-var-config
}
