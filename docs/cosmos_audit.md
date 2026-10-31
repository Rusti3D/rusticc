# COSMOS audit for Rusticc — 2026-10-24

What COSMOS (OpenCentauri, `D:\Carbon Centauri\cosmos`) changes in or around Kalico. For each change: what it is, why
COSMOS did it (from the commit that brought it in), and what Rusticc does with it. Rusticc is COSMOS with
klippy replaced by kaliru (Rust). Its parity reference is "COSMOS klippy" = Kalico 5b59427 plus the COSMOS
patch set, built by `tools/make_ref.sh`.

Sources: `meta-opencentauri/recipes-apps/klipper/` (kalico_2026.02.00.inc/.bb, files/*), `recipes-data/klipper-afc-addon/`,
COSMOS git log, and read-only inspection of the user's CC1 (192.168.1.148).

## Verdict

- Rusticc makes sense as planned. Every COSMOS klipper change is either:
  - small host logic to port into kaliru (8 patches, 2 extras); or
  - MCU firmware (3 patches; the HiFi4 one is the hard part); or
  - a Python-interpreter optimisation with no meaning for a Rust binary.
  
  None of them conflicts with kaliru's design.
- The COSMOS Python tuning exists for memory: the CC1 has 128 MiB, and shaper calibration peaked at 101 MB with the camera and GUI running. That is the problem Rusticc solves at the root, so Rusticc measurements must include shaper calibration memory, not just idle and printing.
- Two facts change the plan's weight (details under [Addons](#addons-on-the-users-cc1)):
  - The user's CC1 runs about 31k lines of Python addons: AFC, AFC_ACE, knock and gamepad_jog.
  - canvas_rfid loads the OpenRFID Python library at runtime.
  
  Rusticc on this printer is not usable without AFC. The python-addon question is therefore on the critical path for the CC1 test, not "later".

## Base version

| | Kalico commit |
|---|---|
| COSMOS (`SRCREV`) | 0057b6a (COSMOS 26.10.0; 26e46bd before) |
| kaliru | 550d21fb (5b59427 before) |

2026-10-31: COSMOS 26.10.0 moved to Kalico 0057b6a (5b59427 + 8). kaliru ported upstream Kalico to 550d21fb
(0057b6a + 13: spi_flash, mcu wrapper errors, dummy query responses, ack waits failed on timeout, tests). The
reference is now 550d21fb plus COSMOS's patches (the cosmos submodule), and the image's python klippy tree stays
COSMOS's 0057b6a.

kaliru's base is 58 commits newer than COSMOS's. The klippy side of those 58 commits:
- the mcu.py split into helper classes and the error_mcu module;
- reactor pause checks;
- `[include]` variables (38724040, 4f9a5789);
- tmc5262;
- SET_NOZZLE_DIAMETER;
- non-critical-MCU fixes (95ab819a, 68764993);
- resonance_tester motion limits (8497e5ad).

**Decision:** Rusticc stays on 5b59427. COSMOS will reach it on its next Kalico bump, and kaliru already has byte-level parity there. The reference is 5b59427 plus COSMOS's patches, not COSMOS's exact tree.

## Patches (`kalico_2026.02.00.inc` SRC_URI, in apply order)

### How the patches were checked against our base

Bitbake applies patches with `patch`, not `git apply`. `git apply --check` rejects all twelve, even on 26e46bd, because the files are hand-edited (no index lines; one has no trailing newline). With `patch -p1 --dry-run`, applied cumulatively in recipe order:
- On 26e46bd: all apply.
- On 5b59427: all apply except two:
  - resonance-tester: "Reversed (or previously applied)", because it is upstream.
  - allow-config-exclude: hunk fails, because of the include-variables rewrite. It is rebased in `reference-patches/0004-allow-config-exclude.patch` and verified (below).

### Host-side patches

| Patch | What | Why (COSMOS commit) | Rusticc |
|---|---|---|---|
| 0001-remove-save-config-subfile-check | Drops `_strip_duplicates` on load and `_disallow_include_conflicts` on SAVE_CONFIG | Full-calibrate rework (#74 5390899, #174 4734a50). SAVE_CONFIG must be able to save values that also appear in the read-only include files. | Port to kaliru configfile. Applies to 5b59427 at offset 68; 5b59427 also calls `_strip_duplicates` at :828/:857 for `autosave_includes`, which the patch leaves alone. |
| 0002-reduce-calibration-difference-tolerance | Load-cell guided calibration: tare-vs-cal threshold from 1.0 % to 0.1 % | #174: the CC1 load cell's span is small, so 1 % rejected valid calibrations. | Port (one constant plus message). |
| 0001-Reduce-log-rotate-threshold | queuelogger: `RotatingFileHandler(maxBytes=5 MiB, backupCount=2)` instead of the Timed handler | Storage. The log is at `/board-resource/klippy.log`; logrotate and cron were removed (#172 5c075bb, f39c95b). | Port. kaliru's queuelogger implements TimedRotatingFileHandler only, so a size-based rollover (CPython `RotatingFileHandler.shouldRollover`/`doRollover` semantics) must be added. |
| 0001-implement-pulldown-resistor-in-thermistor-calc | `pulldown_resistor` option (thermistor and custom thermistor): parallel-resistor correction in calc_temp/calc_adc; r is clamped to 1e-7 before log | CC1 hardware: the CANVAS toolhead board has a 100k pulldown in parallel (#155 702676a). machine.cfg emergency-stops ("Fire hazard") if a CANVAS board is detected and `pulldown_resistor != 100000`. | Port. Safety-relevant: a wrong temperature reading is a fire risk, so it needs a case test with the value set. |
| 0001-probe-home-z-includes-z-offset | Probe "home z" sets z = pos − last_z_result **+ z_offset** | #155: homing Z with the load-cell probe ignored z_offset. | Port (one line, probe.rs set_position path). |
| 0001-force-specific-input-shaper | `SHAPER_CALIBRATE FORCE_SHAPER=<name>`, validated against `shaper_defs.INPUT_SHAPERS` | #223 8455d18: FULL_CALIBRATION forces MZV. | Port. |
| 0003-drv8833-motor-control | New `[drv8833]` extra plus MCU `src/drv8833.c`; `WANT_DRV8833` defaults to y with HARD_PWM | CANVAS lane motors via AFC (#170 80c1fe0). Used by afc-addon `canvas.cfg` `[drv8833 canvas_laneN]`. | Port host extra and MCU module (firmware: every STM32 build gets it by default). |
| 0004-allow-config-exclude | `[!section]` removes an already-defined section; error if missing | #170: AFC's `afc.cfg` does `[!gcode_macro LOAD_FILAMENT]` and `canvas.cfg` does `[!filament_switch_sensor filament_sensor]`. | Port the rebased version. |
| 0001-Increase-max-velocity-in-resonance-tester | Motion limits derived from the test sequence | #245 098b0ec: it was cherry-picked from KalicoCrew/kalico#912 to stop OOMs during shaper calibration ("max observed memory usage was 101Mb" with camera and GUI). | **Already in kaliru**: identical to upstream 8497e5ad, which is in 5b59427 and ported. Nothing to do. |

### Firmware patches

| Patch | What | Why (COSMOS commit) | Rusticc |
|---|---|---|---|
| 0005-stm32-serial-rs485-de-pin | STM32 USART drives an RS-485 DE pin (TC interrupt release, turnaround wait) | CC2 canvas (5dc0dc7). Only `centauri-carbon-2/config.canvas` sets `STM32_SERIAL_RS485=y`. | Port to the kaliru firmware stm32 serial. Not needed on the CC1. |
| 0006-Add-support-for-hifi4 | New `MACH_HIFI4` board: Allwinner R528 HiFi4 DSP, plus lib/hifi4 HAL. Built with `gcc-xtensa-hifi4-elf-native` (Zephyr SDK gcc `xtensa-nxp_rt700_hifi4_zephyr-elf-`, `-O0 -mabi=call0`). | The CC1 mainboard MCU *is* the DSP (`[mcu] serial: /dev/ttyRPMSG0`). | Needed for the CC1. Rust has no Xtensa-HiFi4 LLVM target, but COSMOS builds it with GCC, so it can go the same route as AR100/PRU: rustc_codegen_gcc on that GCC. Until then Rusticc can ship COSMOS's C DSP image unchanged; the host protocol is the same. |
| 0007-Add-HX711s-load-cell-probe-driver | `sensor_type: hx711s` load-cell module plus MCU `sensor_hx711s.c` | The CC1/CC2 load-cell probe (`[load_cell_probe] sensor_type: hx711s` in machine.cfg). `WANT_HX711S=y` on bed, toolhead, canvas and afc-lite. | Port host and MCU. The CC1 cannot probe without it. |

The rebased 0004 was verified on 5b59427 with the full set applied:
- an include defining `[foo]`/`[bar]` followed by `[!foo]` leaves `['bar','baz']`;
- `[!nope]` raises "Section 'nope' does not exist for exclusion";
- every patched file passes `py_compile`.

## Extras added as files

| File | What | Rusticc |
|---|---|---|
| canvas_rfid.py (397 lines) | CANVAS NFC reader over MCU I2C (0x50); decodes tags with **OpenRFID** loaded via `importlib` from `/usr/share/openrfid` (267 KB of Python on the CC1) (684f9d9, 79166a0) | Port the extra. The OpenRFID processors it calls must be ported too, or run through the addon host. |
| canvas_filament_sensor.py (408 lines) | CC2 filament sensor as a virtual pin chip on RS-485 (CRC8/CRC16 frames); emulates `buttons_state` replies (5f73c50) | Port (pure host logic; it depends on MCU_buttons internals, which kaliru has). |

## Build and packaging (kalico_2026.02.00.bb)

| Item | Rusticc |
|---|---|
| c_helper built `-O2 -flto -fwhole-program ${CFLAGS}`. With the Cortex-A7 NEON-VFPv4 flags GCC contracts to FMA (36 `vfma.f64` in the shipped c_helper.so), so CC1 results differ in the last bits from x86 Kalico (rotary_delta_calibrate 0.06898506297310092 vs 0.06898506297319008). This is a side effect of the build, not a COSMOS decision. | kaliru follows the C source's IEEE semantics, which is the same as the `-ffp-contract=off` reference. **User decision pending** (recommended: source semantics). |
| `sed APP_NAME = "Kalico"` → `${DISTRO_NAME}`; `.version` = "Release - ${DISTRO_VERSION}" | Rusticc build sets `printer::APP_NAME` to "Rusticc" and writes the version file the same way. |
| `compileall --invalidation-mode checked-hash` | Python-only, n/a. |
| `/etc/klipper/plugins` (Kalico plugin dir) | Same directory: it is where the user's plugins live (below). |
| Config layout: `printer.cfg`, `klipper-readonly/`, `extras-readonly/`; `build-klipper-var-config` | Unchanged; these are config files and shell, not klippy. |

## Init script (klipper-init-d) and system tuning

| Change | Why | Rusticc |
|---|---|---|
| `-X lazy_imports=all` | Interpreter memory, Python 3.15 (ab6fe92) | n/a (no interpreter). |
| `-X no_debug_ranges` | Smaller code objects (#271 f30c605) | n/a |
| `-OO` added (#70 5c14bc7), later `-O` dropped (#271) | It was measured to cost klippy +1.1 MiB RSS. Klippy therefore runs **with asserts on**. | Matches: klippy's only `assert` (display/menu.py:377 `assert_recursive_relation`) is an active check in kaliru `menu.rs:822`. |
| `TMPDIR=/user-resource/.tmp` | Shaper/PID CSVs filled the RAM disk (#188 e848e46). Kalico itself switched to `tempfile.gettempdir()`. | kaliru `pyglob::gettempdir` reads TMPDIR/TEMP/TMP. **Gap:** CPython also falls back to /var/tmp, /usr/tmp and cwd, and only accepts a dir it can write a test file into. Port that for exact parity. |
| `-l /board-resource/klippy.log -a /run/klippy.sock` | Paths | Same arguments. |
| CPython PGO + LTO (a5885f5, "roughly one fifth" faster) | CPU | The Rust analogue is phase-2 work (LTO is in place; PGO is optional). |
| zram 200 % LZ4, no swap (ef2e300, 29dbade); kernel footprint cuts (#256) | Memory | System-level; Rusticc keeps them unchanged. |

## Addons on the user's CC1

Read-only on 2026-10-24.

| Addon | Size and location |
|---|---|
| AFC (`klipper-afc-addon`, suchmememanyskill/AFC-Klipper-Add-On@0fd50f2) | 32 `AFC*.py` files in `klippy/extras`, **26,528 lines** |
| `/etc/klipper/plugins`: AFC_ACE, knock, gamepad_jog | 4,786 lines (`*.py` in AFC_ACE + knock) and 348 lines (gamepad_jog) |
| OpenRFID | 267 KB |

`printer.cfg` includes `../plugins/AFC_ACE/config/cc1-toolhead.cfg`.

So Rusticc has two ways to run this printer's real config:
1. **Embedded addon host:** load Python only when a config section needs a non-built-in module. The no-plugin cost is zero. With AFC loaded, the cost must stay at or below what klippy costs today (34 MB RSS measured on the CC1). This is the user's constraint.
2. **Native ports:** AFC and the user's plugins in Rust. This is the most memory-efficient option, but it means about 31k lines that follow a separate upstream.

Recommendation: (1) first, as the general mechanism, because it also covers knock, gamepad_jog and future addons. Port OpenRFID and canvas_* natively, since COSMOS ships them in-tree. Decide on native AFC from measurements.

## Firmware map (which board needs what)

| MCU | Chip and link | COSMOS-specific features |
|---|---|---|
| mainboard | HiFi4 DSP, `/dev/ttyRPMSG0` (rpmsg tty, no host transport change) | MACH_HIFI4 (0006) |
| bed | STM32F401, USART2 `/dev/ttyS4` @ 250000 | HX711S, DRV8833 (default) |
| hotend/toolhead | STM32F401, USB | HX711S, DRV8833 |
| canvas | STM32F401, USB (CC2: RS-485 serial) | HX711S, DRV8833, RS485 on CC2 |
| afc-lite | STM32H723, USB | HX711S, DRV8833 |

CS1237 is upstream (55d7d62 bumped Kalico for it) and is already ported in kaliru.

## Rusticc work list from this audit

1. Port into kaliru's Rusticc build:
   - the 8 host patches;
   - canvas_rfid with OpenRFID;
   - canvas_filament_sensor;
   - the drv8833 extra;
   - the hx711s host module.
   
   Prove parity against `make_ref.sh`'s tree with the existing harnesses (case/suite/config/save/live).
2. Firmware:
   - port drv8833, sensor_hx711s and the RS-485 DE pin;
   - port HiFi4 via rustc_codegen_gcc, or ship COSMOS's C image meanwhile.
3. Close the queuelogger size-rotation and the gettempdir gaps (above).
4. Addon host design under the memory constraint, needed for AFC on the CC1.
5. CC1 measurements must include SHAPER_CALIBRATE memory peak (COSMOS's documented 101 MB worst case).

## Where Rusticc's code lives (decided 2026-10-24)

- Rusticc is kaliru branch **`rusticc`**, checked out as a git worktree at `D:\RustyKlipper\Rusticc`. kaliru `main`
  stays byte-identical to Kalico.
- Each COSMOS change is its own commit on `rusticc`, named after the COSMOS patch. That is the same model as COSMOS
  patching Kalico, and the branch rebases onto `main` when kaliru moves.
- Rusticc-only material lives in `rusticc/` on that branch: this audit, `tools/make_ref.sh`, `patches/` and the
  logo.
- Parity reference: `make_ref.sh` (Kalico 5b59427 + COSMOS patches). It is compared with the same harnesses as kaliru,
  via `REF_KALICO=<tree>` (case_cmp/suite_cmp).

## Verification commands

- Patch applicability: `patch -p1 -N --dry-run`, cumulative in recipe order, on `git archive 26e46bd` and `git archive 5b59427`.
- Reference tree: `bash tools/make_ref.sh /tmp/cref` (WSL). It applies cleanly; the "patch unexpectedly ends in middle of line" warning comes from 0001-remove-save-config-subfile-check lacking a final newline and is harmless.
- CC1 facts: `ssh root@192.168.1.148` with `ls`, `wc -l` and `grep` only.
