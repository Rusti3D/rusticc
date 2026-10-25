# Rusticc's releases and commits: github.com/Rusti3D/rusticc
do_install:append() {
    sed -i -e 's#OpenCentauri/cosmos#Rusti3D/rusticc#g' \
        -e 's#from COSMOS version#from Rusticc version#' ${D}${bindir}/check-update
}
