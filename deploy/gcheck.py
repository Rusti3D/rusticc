# Read-only hardware check: runs g-code commands through klippy's API socket
# and prints each command's responses (gcode/subscribe_output), so stock
# klippy and Rusticc can be compared on the printer. Nothing here moves.
# usage: python3 gcheck.py COMMANDS_FILE > out.txt
import json
import socket
import sys
import time

SOCK = "/run/klippy.sock"


class Api:
    def __init__(self):
        self.s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.s.connect(SOCK)
        self.s.settimeout(0.2)
        self.buf = b""
        self.id = 0
        self.out = []

    def _pump(self, until=None, wait_id=None, timeout=30.0):
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            while b"\x03" in self.buf:
                msg, self.buf = self.buf.split(b"\x03", 1)
                m = json.loads(msg)
                if m.get("method") == "gcode_output":
                    self.out.append(m["params"]["response"])
                elif wait_id is not None and m.get("id") == wait_id:
                    return m
            if until is not None and time.monotonic() >= until:
                return None
            try:
                data = self.s.recv(65536)
            except socket.timeout:
                continue
            if not data:
                return None
            self.buf += data
        return None

    def request(self, method, params, timeout=30.0):
        self.id += 1
        self.s.sendall(json.dumps({"id": self.id, "method": method, "params": params}).encode() + b"\x03")
        return self._pump(wait_id=self.id, timeout=timeout)


def main():
    api = Api()
    api.request("gcode/subscribe_output", {"response_template": {"method": "gcode_output"}})
    for line in open(sys.argv[1]):
        cmd = line.strip()
        if not cmd or cmd.startswith("#"):
            continue
        api.out = []
        res = api.request("gcode/script", {"script": cmd})
        # (responses that arrive just after the request finishes)
        api._pump(until=time.monotonic() + 0.5)
        err = res.get("error", {}).get("message") if res else "(no answer)"
        print("> " + cmd)
        for r in api.out:
            print(r)
        if err:
            print("error: " + err)


if __name__ == "__main__":
    main()
