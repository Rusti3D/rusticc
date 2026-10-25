# Rusticc status

Rusticc is COSMOS (OpenCentauri's firmware for the Elegoo Centauri Carbon) with Kalico replaced by Kaliru, the Rust port of Kalico.
Its logo is `branding/Rusticc.png`, which replaces the OpenCentauri/COSMOS logo.

## Queue (user, 2026-10-25, in order)

- [x] Full AFC parity where Rusticc needs it: native AFC for COSMOS's stock Canvas (patch 0021, docs/AFC_PORT.md).
  9/9 batch Canvas runs identical (`tools/canvas_cmp.sh`); drv8833 lane moves can't run in batch (no MCU replies).
- [ ] A native Rust AFC build for cosmoace_afc (AFC_ACE, the user's CC1 config).
- [ ] Then the real Rusticc build, for the user to try on the printer (install only with their go).
- [ ] Address any issues; then full AFC parity as its own project (rust afc).
- [ ] Gaps in Rusticc / kaliru: camera support, "nothing should be breaking on my cc1".

## How the code is organised

- kaliru (github.com/Rusti3D/kaliru) is Kalico in Rust, identical to Kalico. Rusticc's changes to it are the patch
  series in `meta-rusticc/recipes-apps/rusticc/files/kaliru`, one patch per change (the COSMOS patch it ports, or
  a Rusticc addition such as the profilers); `tools/kaliru-tree.sh` / `kaliru-export.sh` work on them.
- The reference for parity is Kalico 5b59427 with COSMOS's patches applied (`tools/make_ref.sh DEST`).
- `docs/cosmos_audit.md` covers every COSMOS change: what it does, why COSMOS made it, and what Rusticc does about it.
- `reference-patches/` holds the COSMOS patches that had to be rebased onto 5b59427 for the reference.

## Status (2026-10-25)

Ported and checked against the COSMOS reference (`tools/ref_setup.sh`, then `tools/case_cmp.sh`):
the host patches 0001-remove-save-config-subfile-check, 0002-reduce-calibration-difference-tolerance,
0001-Reduce-log-rotate-threshold, 0001-implement-pulldown-resistor-in-thermistor-calc, 0001-probe-home-z-includes-z-offset,
0001-force-specific-input-shaper, 0004-allow-config-exclude, and the hx711s/hx717s load cell (0007). The full case set
(Kalico tests + kaliru cases + Rusticc cases) is 171/172 identical (printers/13 is a known timing case); the CC1
config and the plugin cases are identical too. The tree is kaliru main ce214e3 + patches 0001-0021.

`tools/cc1_cmp.sh` runs the user's CC1 config (AFC, AFC_ACE, knock) in batch mode with the printer's own MCU
dictionaries (`dicts/`). Startup is identical to COSMOS. `CANVAS=1 tools/cc1_cmp.sh cases/cc1_canvas.gcode` runs
COSMOS's stock config with the Elegoo Canvas instead (the AFC port's parity run, docs/AFC_PORT.md).

Every COSMOS host module is ported (2026-10-25, patches 0015-0017): drv8833 (CANVAS lane motors
and their PID tune), canvas_filament_sensor (the CC2 RS-485 sensor as button pins, through
`buttons::ButtonsHost`) and canvas_rfid (the CANVAS NFC reader; OpenRFID's tag decoders run on the plugins'
CPython, imported from `/usr/share/openrfid` as COSMOS does). Their cases are in `cases/` (drv8833*,
canvas_filament_sensor*, canvas_rfid_*). The reader's I2C exchange itself needs a CANVAS board: batch mode has
no MCU replies (the reference hangs on the first poll) and the user's CC1 has no CANVAS.

## Firmware (kaliru-mcu, `firmware/`, 2026-10-25)

COSMOS's MCU patches are ported: 0003 drv8833 (`src/drv8833.rs`), 0005 the stm32 RS-485 driver enable pin
(`src/stm32/serial.rs`), 0007 hx711s (`src/sensor_hx711s.rs`), and 0006 the HiFi4 DSP, the CC1's mainboard MCU
(`src/hifi4/`: the board, the `lib/hifi4` drivers it uses, RPMsg over the msgbox, the startup and vectors).
The board configs are COSMOS's (kaliru's `firmware/configs/cosmos-*`, from `configs/src/cosmos-*.in`):

| config | MCU | requests + dictionary | emulator (`tests/emu_cmp.sh`) |
|---|---|---|---|
| cosmos-cc1-dsp (mainboard) | HiFi4 600 MHz | identical | no Xtensa model; **on the CC1 (2026-10-25): boots, same dictionary, stock klippy + the user's config reach ready on it** |
| cosmos-cc1-bed / toolhead / canvas | STM32F401 | identical | cc1-bed 8/8 |
| cosmos-cc2-bed / toolhead / canvas | STM32F103 | identical | cc2-canvas 8/8 (RS-485 DE accesses identical) |
| cosmos-afc-lite-usb | STM32H723 | identical | 8/8 |

The C references are built from the COSMOS tree (`tools/mkref_cosmos.sh`); their dictionaries equal the ones
of the firmware on the CC1 (`dicts/`). kaliru's `firmware/tests/cosmos/cosmos.script` drives drv8833 (PID and manual)
and hx711s in the emulator. Sizes, C vs Rust (flash or code / static RAM; the DSP copies its read-only data into
its data RAM at boot, so it counts there):

| | C | Rust |
|---|---|---|
| DSP | 31.7 KB code / 8.8 KB data RAM | 19.5 KB / 4.4 KB (same 8 KB heap: same move queue) |
| STM32F401 bed | 44.2 KB / 1.15 KB | 49.4 KB / 0.93 KB |
| STM32F103 canvas (CC2) | 42.5 KB / 1.17 KB | 48.1 KB / 0.95 KB (fits its 48 KB) |

The DSP builds with Espressif's Rust (`xtensa` LLVM, toolchain `esp`) for `firmware/targets/xtensa-hifi4-none-elf.json`
(the call0 ABI, the core options COSMOS's gcc uses) and links with COSMOS's own Zephyr gcc and linker script; see
kaliru's `firmware/tests/ctr_check.sh`. Its resource table is byte-identical to COSMOS's. To try it on the printer (stops klippy,
loads the firmware from `/user-resource/rusticc`, reads its dictionary; a reboot is stock):
`deploy/dsp-test.sh rusticc`, back with `dsp-test.sh stock`.

## Branding (`meta-rusticc`)

A Yocto layer on top of COSMOS's meta-opencentauri: the boot logo, the psplash splash, Fluidd's theme (name, logo,
icon, wordmark), the login banner and the distro name (`DISTRO = "rusticc"`). Every image is made from `Rusticc.png`
by `branding/make_assets.py`, at the sizes and formats of the COSMOS files it replaces.

## Measured on the CC1 (2026-10-25, `deploy/ab.sh`, ab3)

Idle with the user's config (AFC, AFC_ACE, knock, hx711s), each started fresh, measured for 120 s, 9 minutes after
start. A Mainsail tab was open throughout (it subscribes to every object with all fields at 250 ms, through
Moonruster): the same client set for both.

| | stock COSMOS klippy | Rusticc | |
|---|---|---|---|
| CPU idle | 11.97 % | 8.78 % | -27 % |
| CPU used in the first 9 minutes | 77.8 s | 52.7 s | -32 % |
| anonymous memory (RAM + swap) | 25.1 MB | 17.4 MB | -31 % |
| RSS (+ swapped out) | 32.0 + 3.3 MB | 28.7 + 1.6 MB | |
| PSS | 30.7 MB | 27.5 MB | |
| MemAvailable (whole printer) | 42.0 MB | 49.3 MB | +7.2 MB |

Read-only g-code check (`deploy/gcheck.py gcheck_cmds.txt`, stock vs Rusticc, numbers masked): 432 lines each,
the same except the HELP list (COSMOS's Kalico 26e46bd has the telemetry commands, kaliru's 5b59427 has
SET_NOZZLE_DIAMETER), live counters and a periodic shell macro's output. Hardware reads work: TMC dumps, LIS2DW
(WHO_AM_I 0x44, gravity), the hx711s load cell (933 samples, no errors), probe, temperatures.

No memory growth over a 40-minute idle run (`deploy/leak.sh`): anonymous memory 15,532 kB at 10 minutes,
15,536 kB at 40 minutes; CPU 8.65 / 8.67 %.

Run it: `bash tools/build_cc1.sh`, copy the binary and `deploy/*` to `/user-resource/rusticc` on the
printer, stop COSMOS's klippy (`/etc/init.d/klipper stop`) and start `rusticc-run.sh`. `/etc/init.d/klipper start` goes
back to stock.
