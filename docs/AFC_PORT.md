# Native AFC port

Goal (user, 2026-10-25): AFC and AFC_ACE run natively in Rusticc, parity-checked
against the Python AFC, so the CC1 no longer runs ~17 MB of Python for them.
Python plugins keep working: a native module wins over a Python one of the same
name; `[danger_options] use_python_modules:` picks the Python one per module.

## Reference

- AFC core: `Originals_Base/addons/afc_extras/*.py`, identical (md5) to the
  CC1's `/usr/share/klipper/klippy/extras/` (AFC.py abdfa943…, AFC_lane.py 0b85b54e…).
- AFC_ACE: `Originals_Base/addons/plugins/AFC_ACE/AFC_ACE.py`, identical to the
  CC1's `/etc/klipper/plugins/AFC_ACE/AFC_ACE.py` (54b89a8e…).
- CC1 config: `printer.cfg` includes `../plugins/AFC_ACE/config/cc1-toolhead.cfg`
  (afc.cfg, afc-ace*.cfg, cc1-head.cfg) plus `[AFC_ACE ACE_1]`, `[AFC_lane lane1]`.

## Stage 1 scope: COSMOS's stock Canvas (user, 2026-10-25)

"keep the initial scope to what cosmos runs with the canvas": `elegoo_canvas`
in cosmos.conf adds `[include ../extras-readonly/canvas.cfg]` (afc.cfg,
canvas-toolhead.cfg, canvas_rfid.cfg; drv8833 and canvas_rfid are already
native). Sections: [AFC], [AFC_prep], [AFC_hub toolhead_4way_hub],
[AFC_extruder extruder], [AFC_canvas CANVAS_1], 4x [AFC_canvas_lane].
Modules: AFC, AFC_functions, AFC_lane, AFC_unit, AFC_extruder, AFC_hub,
AFC_prep, AFC_error, AFC_spool, AFC_stats, AFC_assist (Espooler per lane),
AFC_utils, AFC_logger, AFC_respond, AFC_canvas, AFC_canvas_lane.
Not in stage 1: AFC_stepper, AFC_buffer, AFC_led, AFC_form_tip (only with
form_tip_cmd AFC), AFC_poop, AFC_ACE and the other unit types.
Parity run: `CANVAS=1 tools/cc1_cmp.sh cases/cc1_canvas.gcode` (COSMOS's stock
printer.cfg, the canvas include, cc1_canvas.dict).
Canvas lanes have no stepper: moves go to drv8833 (drv8833_move(speed, dist,
wait_for_completion), drv8833_set_speed, .active); LEDs are two PWM pins.

## Why the whole family moves at once

`afcACE` subclasses the Python `afcUnit` and calls into AFC_lane / AFC_extruder
objects; AFC core modules call each other's methods directly. A native module
can't stand among Python ones, so the family switches over together. Until the
last module is done, Python AFC keeps running.

## Modules the CC1 loads (lines of Python)

| module | lines | | module | lines |
|---|---|---|---|---|
| AFC | 3232 | | AFC_utils | 998 |
| AFC_functions | 2162 | | AFC_spool | 981 |
| AFC_lane | 2554 | | AFC_stepper | 929 |
| AFC_unit | 1156 | | AFC_assist | 923 |
| AFC_extruder | 1237 | | AFC_stats | 483 |
| AFC_buffer | 1593 | | AFC_error | 400 |
| AFC_ACE | 2999 | | AFC_prep | 315 |
| AFC_hub | 268 | | AFC_logger | 253 |
| AFC_form_tip | 225 | | AFC_led | 167 |
| AFC_respond | 110 | | AFC_poop | 114 |

Order: leaves first (logger, respond, utils, error, stats, led, hub), then
stepper, lane, unit, extruder, buffer, spool, form_tip, poop, prep, assist,
functions, AFC, AFC_ACE.

## Parity decisions

- AFC.log: `log_frame_data` defaults to True, so each line carries the Python
  caller's `[file:function():co_firstlineno]` padded to the widest seen. The
  native port keeps it: each method has its Python (file, name, def line).
- The harness does not compare AFC.log yet (refrun/refdiff copy klippy.log,
  output, trace); add it for AFC cases, with the monotonic stamps normalised.

## Module notes

### AFC_logger
- AFC.log: own QueueListener (kalico signature `(filename, False)`, no
  rollover), formatter `%(asctime)s %(message)s`, datefmt `%H:%M:%S`; logger
  propagate False, level DEBUG. No log_file start arg: the root logger instead.
- Line: `{monotonic:10.3f} {frame:<pad}- {msg}` with tags `<.*?>` removed and
  msg lstripped; frame `[{basename}:{func}():{firstlineno}] ` padded to the
  widest seen so far (padding grows also when log_frame_data is off: len("")).
- Prefixes: raw `{'RAW:':^7}`, info `{'INFO:':^6}`, warn `{'WARN:':^6} `,
  debug `{'DEBUG:':^6}`, error `{'ERROR:':^6}{stack_name}`. raw/warn/debug/error
  split `msg.lstrip().rstrip()`; info splits `msg.lstrip()` only.
- send_callback: every gcode output callback whose owner is a webhooks
  GCodeHelper gets `msg.lstrip()` (so: API clients subscribed to gcode output,
  not the console/serial). warning: `<span class=warning--text>WARNING: {msg}</span>`;
  error: `!! {msg}`; warning/error append (msg, kind) to afc.message_queue
  (error: msg.lstrip()). debug goes to clients only with print_debug_console.

### AFC_respond
- AFCprompt: `// action:prompt_*` lines via logger.raw.

### AFC_utils
- add_filament_switch: synthetic `[filament_switch_sensor X]` (switch_pin,
  pause_on_runout False, debounce_delay 0.0, `extruder` with no value),
  pins.allow_multi_use_pin(pin.strip("!^")); hidden sensors are renamed to
  `_filament_switch_sensor X` in printer.objects; runout_helper.sensor_enabled
  = enable_runout, runout_pause False; with a runout callback: insert_gcode None,
  runout_gcode 1, _runout_event_handler replaced. DebounceButton replaces
  runout_helper.note_filament_present (kalico signature: eventtime,
  is_filament_present, force, immediate -> _button_handler(eventtime, state);
  the debounced action calls the old function, TypeError -> (eventtime, state);
  any exception -> pause_resume.cmd_PAUSE directly).
  Native needs hooks on kaliru's filament_switch_sensor: build from a synthetic
  section, rename the object, replace the runout handler and the
  note_filament_present entry point.
- AFC_moonraker: HTTP to moonraker (urllib, 10 s timeout) with one background
  writer thread for fire-and-forget POST/DELETE; results/log calls go back via
  register_async_callback. Native: a small HTTP/1.1 client on TcpStream.
  Python tracebacks it writes to AFC.log (format_exc) cannot match natively.
- VirtualFilamentSensor/VirtualRunoutHelper: FPS virtual pins (not used on CC1).
- natural_sort_key: digit runs as ints, other chunks lowercased.

## Native layout (decided)

- `src/extras/afc/`: one file per Python module (mod.rs = AFC.py, functions,
  lane, unit, canvas, canvas_lane, extruder, hub, prep, error, spool, stats,
  assist, utils, logger, respond); registered as AFC, AFC_functions, AFC_spool,
  AFC_error, AFC_prep, `AFC_hub `, `AFC_extruder `, `AFC_canvas `,
  `AFC_canvas_lane ` (prefix modules).
- Objects are `Rc<...>` with Cell/RefCell fields; cross links (afc.lanes,
  unit.lanes, hub.lanes, extruder.lanes) hold Rc, back links Weak where a cycle
  would leak at restart.
- Python subclass overrides: unit = `UnitBase` + `UnitKind` (Canvas only in
  stage 1); lane = `AfcLane` + `LaneKind` (Canvas: drv8833 motor, LED pins,
  odometer). Methods that subclasses override dispatch on the kind; the
  `hasattr(unit, "unit_load_lane")` style checks become kind checks.
- `gcode_move.last_position` is aliased in Python (`newpos =
  gcode_move.last_position; newpos[2] = ...; move_with_transform(newpos)`):
  the native code writes gcode_move's own position the same way.
- Python enum reprs in messages: State/AFCLaneState are str enums (str() is the
  value); SpeedMode/AssistActive/AFCMoveWarning are plain Enums
  (str() = "SpeedMode.LONG") - check each formatted use.

## AFC.py facts worth keeping
- AFC_VERSION 1.2.7; print_version runs `git -C <extras dir> rev-parse --short
  HEAD` / `rev-list HEAD --count` ('_' on failure; the failure traceback goes
  to AFC.log as debug) and logs `AFC Version: v1.2.7-<count>-<hash>` (info).
- Registers: pins chips afc_virtual_bypass, afc_quiet_mode (virtual pins for
  add_filament_switch); webhooks endpoint afc/status (response key "status:"
  with the colon, as in Python); events afc_stepper:register_macros,
  virtual_sdcard:reset_file, extruder:activate_extruder; M104/M109 renamed to
  _AFC_RENAMED_M104_/_M109_ via function._rename.
- save_vars: skipped until prep_done; JSON indent=4 to `VarFile + '.unit'`
  via a writer thread (tmp + fsync + os.replace).
- _webhooks_status / get_status key order as in the source.

## Native or Python, per config (decided)
The native AFC family is used only when the config is inside the native scope:
every `[AFC*]` section is one stage 1 ports (AFC, AFC_prep, AFC_hub,
AFC_extruder without toolchanger_unit / tool / u1_* / virtual or buffer
pin_tool_start, AFC_canvas, AFC_canvas_lane), with no AFC_buffer, AFC_stepper,
AFC_led, other unit types or `[danger_options] use_python_modules` naming AFC.
Anything else loads the Python AFC exactly as before (with a klippy.log info
line saying why), so an ACE / BoxTurtle / toolchanger setup keeps working.

## Python quirks the port keeps (they shape the output)
- AFC_prep.PREP: `cur_lane.unit_obj.lanes.append(...)` (dict: AttributeError
  if the lane were missing; it never is after connect) and, with an old
  `hub_loaded` key in AFC.var.unit, `lane.loaded_to_hub = ...` on the lane NAME
  (str): AttributeError "'str' object has no attribute 'loaded_to_hub'".
- AFC_functions.cmd_SET_BOWDEN_LENGTH uses `self.current` (no such attribute):
  AttributeError whenever HUB is missing.
- AFC_error.AFC_error / handle_lane_failure: stack_name = the caller's function
  name; native callers pass their Code.
- AFC.TOOL_LOAD returns before restore_toolhead_temp only through `finally`
  (restore always runs); CHANGE_TOOL catches every exception, logs
  "Unexpected error during CHANGE_TOOL:\n" with the traceback (a Python stack:
  cannot match natively) and AFC_error's it; next_lane_load = None in finally.
- afcDeltaTime, AFC.log times and moonraker tracebacks are wall clock / Python
  stacks: AFC.log comparison normalises them.

## Found on the way
- Python AFC with the stock Canvas config does not start on Rusticc today: the
  plugin layer does not mirror `PrinterPins.setup_pin` (AFC_canvas's enable
  pins, AFC_canvas_lane's LED pins; also BoxTurtle espoolers). A genuine kaliru
  fix: setup_pin plus MCU_digital_out / MCU_pwm wrappers (setup_start_value,
  setup_cycle_time, setup_max_duration, set_digital, set_pwm, get_mcu, and a
  settable `last_set_time`). Queued after the native port's first parity run.
- Without a log file (batch tests) AFC logs through the root logger, so its
  lines are in klippy.log; Python tracebacks inside them (CalledProcessError
  from print_version's git calls) need frame normalisation in refdiff.

## Stage 2: cosmoace_afc, the ACE units (user, 2026-10-25)

"a native rust afc build for cosmoace_afc": the user's CC1 runs the
cosmoace_afc plugin (`plugins/AFC_ACE`, AFC_ACE.py, identical on the printer
and in `Originals_Base`). Native files: `ace.rs` (afcACE, AceSetup, the dryer
heater and humidity sensor) and `ace_transport.rs` (AceTransport, the ACE
Pro's thread with its framed JSON; Ace2Bus / Ace2Transport, the ACE 2's shared
RS-485 bus with protobuf). Each transport runs on its own thread as in Python;
the reactor submits requests and polls them with `reactor.pause`.

- Scope: `[AFC_ACE]`, `[AFC_ACE <unit>]` and `[AFC_lane]` sections of an ACE
  unit (or an override without a unit line) are native too; the plugin
  directory is then skipped (printer.rs load_py_modules). AFC_lane lanes of any
  other unit, a selector, step_pin, buffer or LED index keep the Python AFC.
- AFC core hooks Canvas did not need: `unit_load_lane` / `unit_unload_lane`
  (load_sequence / unload_sequence), `get_lane_reset_command` (AFC_LANE_RESET),
  stepperless `lane_move` (move_advanced), "ACE" in ONLY_LOAD_TYPES and
  EXCLUDE_TYPES (the plugin appends it at import), the base afcUnit LED states
  and calibration prompts.
- AFC.log frame data: `tools/afc_codes.py <afc_extras> <AFC_ACE.py>`.
- Parity: `tools/ace_cmp.sh` runs the CC1 config against `tools/fake_ace.py`
  (an ACE Pro on a pty; `--events` puts spools in or takes them out). Batch mode
  has no temperatures or sensor readings, so `ACE_OFFLINE_LOADS=1` lets loads
  run (0 C materials, cold extrusion, no toolhead sensor). The serial thread's
  log lines compare as their own sequence (refdiff), its `t=` and durations
  masked; AFC's Δt timings and the shutdown stop burst too.
- The reference venv's pyserial is 3.5, as on COSMOS (3.4 doubles "read
  failed:" on a disconnected device).
