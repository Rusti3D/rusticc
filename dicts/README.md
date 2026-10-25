Data dictionaries of the user's CC1 MCU firmware (COSMOS, Kalico 26e46bd),
extracted from /lib/firmware on the printer (2026-10-24): the zlib-compressed
JSON each image embeds. Used by tools/cc1_cmp.sh.

| File | Firmware | MCU |
|---|---|---|
| cc1_dsp.dict | rproc-1700000.dsp-fw | [mcu] (HiFi4 DSP, /dev/ttyRPMSG0) |
| cc1_bed.dict | klipper-bed.bin | [mcu bed] stm32f401xc |
| cc1_toolhead.dict | klipper-toolhead.bin | [mcu hotend] stm32f401xc |
| cc1_canvas.dict | klipper-canvas.bin | [mcu canvas] (not in the user's config) |
