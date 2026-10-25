# The root slot is 134.3 MB and COSMOS's image already fills 132.2 MB of it:
# with Rusticc's binaries added, plain lz4 gives 149.5 MB. lz4hc packs the
# same format tighter (126.4 MB, measured on the 20b31d0 image), and the
# kernel's lz4 decompressor reads it unchanged.
EXTRA_IMAGECMD:squashfs = "-comp lz4 -Xhc"

# Not shipped by Rusticc: Fluidd (Mainsail is the web UI), AtomScreen
# (GrumpyScreen is the screen) and Doom. moonraker-init-d and the GUI
# switcher fall back to Mainsail / GrumpyScreen if one was selected.
IMAGE_INSTALL:remove = "fluidd atomscreen fbdoom"
