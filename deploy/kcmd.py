# One request to klippy's API socket (/run/klippy.sock), printing the reply.
# usage: python3 kcmd.py METHOD [JSON_PARAMS]
#   kcmd.py info
#   kcmd.py gcode/firmware_restart
#   kcmd.py gcode/script '{"script": "M115"}'
import json
import socket
import sys

method = sys.argv[1]
params = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.settimeout(30)
s.connect("/run/klippy.sock")
s.sendall(json.dumps({"id": 1, "method": method, "params": params}).encode() + b"\x03")
buf = b""
while True:
    data = s.recv(4096)
    if not data:
        break
    buf += data
    while b"\x03" in buf:
        msg, buf = buf.split(b"\x03", 1)
        reply = json.loads(msg)
        if reply.get("id") == 1:
            print(json.dumps(reply.get("result", reply.get("error")), indent=1)[:3000])
            sys.exit(0)
