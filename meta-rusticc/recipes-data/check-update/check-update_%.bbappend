# Rusticc's releases and commits: github.com/Rusti3D/rusticc. Versions follow
# COSMOS's CI: a release tag, or the first 10 characters of the commit (nightly)
do_install:append() {
    sed -i -e 's#OpenCentauri/cosmos#Rusti3D/rusticc#g' \
        -e 's#from COSMOS version#from Rusticc version#' ${D}${bindir}/check-update
    # the installed version is /etc/issue's word after DISTRO_NAME: one word
    # for "Rusticc" (two for "OpenCentauri Cosmos")
    sed -i -e 's/\.split(" ")\[2\]/.split(" ")[1]/' ${D}${bindir}/check-update
}
