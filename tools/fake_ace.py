#!/usr/bin/env python3
# A fake Anycubic ACE Pro on a pty, for AFC_ACE parity runs in batch mode.
# Speaks the ACE Pro's frames (FF AA, len LE, JSON, crc16 MCRF4XX LE, FE) and
# answers get_status, feed/unwind (a move takes length/speed/SPEEDUP seconds),
# the stops, feed assist and the dryer.
#   fake_ace.py LINK [--slots ready,empty,ready,empty] [--speedup 20]
#               [--events SECS:SLOT:STATE[:MATERIAL],...]
# LINK is made a symlink to the pty: the config's [AFC_ACE] serial. Events
# change a slot (a spool put in or taken out) SECS after the first motion
# command (batch mode's G4 does not wait in real time; a slow LANE_MOVE does).
import argparse
import json
import os
import pty
import select
import signal
import time
import tty

COLORS = {"PLA": [255, 0, 0], "PETG": [0, 0, 255]}


def crc16(data):
    crc = 0xFFFF
    for byte in data:
        v = byte ^ (crc & 0xFF)
        v ^= (v & 0x0F) << 4
        crc = (((v << 8) | (crc >> 8)) ^ (v >> 4) ^ (v << 3)) & 0xFFFF
    return crc


def frame(payload):
    return (b"\xFF\xAA" + len(payload).to_bytes(2, "little") + payload
            + crc16(payload).to_bytes(2, "little") + b"\xFE")


class Ace:
    def __init__(self, slots, speedup, events):
        self.speedup = speedup
        self.slots = [self.slot(i, s) for i, s in enumerate(slots)]
        self.events = sorted(events)
        self.started = None
        self.motion = {}  # slot -> (state, ends at)
        self.dryer = {"status": "stop", "target_temp": 0, "duration": 0, "remain_time": 0}
        self.assist = None

    @staticmethod
    def slot(i, spec):
        kind, _, material = spec.partition(":")
        return {"index": i, "status": kind, "sku": "", "rfid": 2 if material else 1,
                "type": material, "color": COLORS.get(material, [0, 0, 0])}

    def run_events(self, method):
        if self.started is None:
            if method == "get_status":
                return
            self.started = time.monotonic()
        while self.events and time.monotonic() - self.started >= self.events[0][0]:
            _, index, spec = self.events.pop(0)
            self.motion.pop(index, None)
            self.slots[index] = self.slot(index, spec)

    def status(self):
        now = time.monotonic()
        busy = None
        for i, s in enumerate(self.slots):
            state, end = self.motion.get(i, (None, 0.0))
            if state and now < end:
                busy = state
                s["status"] = state
            elif s["status"] in ("feeding", "unwinding"):
                s["status"] = "ready"
                self.motion.pop(i, None)
        return {"status": "busy" if busy else "ready", "action": busy or "",
                "temp": 25, "humidity": 40, "dryer_status": dict(self.dryer),
                "feed_assist_count": 0, "cont_assist_time": 0.0,
                "slots": [dict(s) for s in self.slots]}

    def call(self, method, p):
        self.run_events(method)
        if method == "get_status":
            return self.status()
        index = p.get("index", 0)
        if method in ("feed_filament", "unwind_filament"):
            if self.slots[index]["status"] == "empty":
                return None
            secs = p["length"] / max(p["speed"], 1) / self.speedup
            self.motion[index] = ("feeding" if method == "feed_filament" else "unwinding",
                                  time.monotonic() + secs)
        elif method.startswith("stop_"):
            if method == "stop_feed_assist":
                self.assist = None
            else:
                self.motion.pop(index, None)
                if self.slots[index]["status"] in ("feeding", "unwinding"):
                    self.slots[index]["status"] = "ready"
        elif method == "start_feed_assist":
            self.assist = index
        elif method == "drying":
            self.dryer = {"status": "drying", "target_temp": p["temp"],
                          "duration": p["duration"], "remain_time": p["duration"] * 60}
        elif method == "drying_stop":
            self.dryer = {"status": "stop", "target_temp": 0, "duration": 0, "remain_time": 0}
        return {}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("link")
    ap.add_argument("--slots", default="ready:PLA,empty,ready:PETG,empty")
    ap.add_argument("--speedup", type=float, default=20.0)
    ap.add_argument("--events", default="")
    args = ap.parse_args()
    events = []
    for e in filter(None, args.events.split(",")):
        secs, index, spec = e.split(":", 2)
        events.append((float(secs), int(index), spec))
    ace = Ace(args.slots.split(","), args.speedup, events)
    master, slave = pty.openpty()
    tty.setraw(slave)
    if os.path.lexists(args.link):
        os.unlink(args.link)
    os.symlink(os.ttyname(slave), args.link)
    signal.signal(signal.SIGTERM, lambda *a: os._exit(0))
    buf = b""
    while True:
        select.select([master], [], [])
        try:
            buf += os.read(master, 4096)
        except OSError:
            # no reader on the other side yet (klippy reopening): keep waiting
            time.sleep(0.05)
            continue
        while True:
            start = buf.find(b"\xFF\xAA")
            if start < 0 or len(buf) < start + 4:
                break
            n = int.from_bytes(buf[start + 2:start + 4], "little")
            end = start + 4 + n + 3
            if len(buf) < end:
                break
            payload, buf = buf[start + 4:start + 4 + n], buf[end:]
            req = json.loads(payload)
            result = ace.call(req["method"], req.get("params") or {})
            if result is None:
                reply = {"id": req["id"], "code": 1, "msg": "slot empty"}
            else:
                reply = {"id": req["id"], "code": 0, "msg": "success", "result": result}
            os.write(master, frame(json.dumps(reply, separators=(",", ":")).encode()))


if __name__ == "__main__":
    main()
