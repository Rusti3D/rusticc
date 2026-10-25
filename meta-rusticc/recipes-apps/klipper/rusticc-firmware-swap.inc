# A kalico-firmware-* recipe with Rusticc's MCU firmware (kaliru-mcu) in
# place of COSMOS's C build: the prebuilt image of files/rusticc-firmware
# (tools/build_firmware.sh) becomes the build's out/klipper.bin
# (.elf for the DSP); COSMOS's install, init script and flashing stay.
require rusticc-firmware.inc

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI += "file://rusticc-firmware/${RUSTICC_FW}"

RUSTICC_PRINTER = "cc1"
RUSTICC_PRINTER:centauri-carbon-2 = "cc2"
RUSTICC_FW_OUT ?= "klipper.bin"

# (no C build: no cross gcc)
DEPENDS:remove = "gcc-arm-none-eabi-native gcc-xtensa-hifi4-elf-native"

# A new .ver: the init scripts flash an MCU whose installed version differs
PR:append = ".rusticc.${RUSTICC_FW_REV}"

do_compile() {
    install -d ${S}/out
    cp ${UNPACKDIR}/rusticc-firmware/${RUSTICC_FW} ${S}/out/${RUSTICC_FW_OUT}
}
