# update-cosmos / flash-artifact fetch Rusticc's images (github.com/Rusti3D/rusticc
# releases and CI artifacts); the image file name stays COSMOS's cosmos-<machine>.swu
do_install:append() {
    sed -i -e 's#OpenCentauri/cosmos#Rusti3D/rusticc#g' ${D}${bindir}/update-cosmos ${D}${bindir}/flash-artifact
}
