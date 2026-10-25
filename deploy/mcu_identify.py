#!/usr/bin/env python3
# Read an MCU's data dictionary over its serial device with Klipper's
# identify command (id 1; identify_response is id 0) and print it as JSON,
# without klippy and without configuring anything: nothing moves.
#   mcu_identify.py /dev/ttyRPMSG0 > dict.json
import json
import os
import select
import sys
import termios
import time
import tty
import zlib


def crc16(data):
    crc = 0xFFFF
    for b in data:
        b ^= crc & 0xFF
        b ^= (b & 0x0F) << 4
        crc = ((b << 8) | (crc >> 8)) ^ (b >> 4) ^ (b << 3)
        crc &= 0xFFFF
    return crc


def vlq(v):
    out = []
    if v >= 0xC000000 or v < -0x4000000:
        out.append((v >> 28) & 0x7F | 0x80)
    if v >= 0x180000 or v < -0x80000:
        out.append((v >> 21) & 0x7F | 0x80)
    if v >= 0x3000 or v < -0x1000:
        out.append((v >> 14) & 0x7F | 0x80)
    if v >= 0x60 or v < -0x20:
        out.append((v >> 7) & 0x7F | 0x80)
    out.append(v & 0x7F)
    return bytes(out)


def parse_vlq(data, pos):
    c = data[pos]
    pos += 1
    v = c & 0x7F
    if c & 0x60 == 0x60:
        v |= -0x20
    while c & 0x80:
        c = data[pos]
        pos += 1
        v = (v << 7) | (c & 0x7F)
    return v, pos


def block(seq, payload):
    msg = bytes([len(payload) + 5, 0x10 | (seq & 0x0F)]) + payload
    crc = crc16(msg)
    return msg + bytes([crc >> 8, crc & 0xFF, 0x7E])


def main():
    fd = os.open(sys.argv[1], os.O_RDWR | os.O_NOCTTY)
    try:
        tty.setraw(fd)
    except termios.error:
        pass
    # (a sync byte ends any partial block the MCU holds)
    os.write(fd, b"~")
    data = b""
    buf = b""
    # (the MCU's first expected sequence number is 0)
    seq = 0
    offset = 0
    while True:
        os.write(fd, block(seq, vlq(1) + vlq(offset) + vlq(40)))
        seq += 1
        got = None
        end = time.time() + 2.0
        while got is None and time.time() < end:
            if select.select([fd], [], [], 0.2)[0]:
                buf += os.read(fd, 4096)
            while len(buf) >= 5:
                n = buf[0]
                if n < 5 or n > 64:
                    buf = buf[1:]
                    continue
                if len(buf) < n:
                    break
                msg, buf = buf[:n], buf[n:]
                if msg[-1] != 0x7E or crc16(msg[:-3]) != (msg[-3] << 8 | msg[-2]):
                    continue
                pos = 2
                mid, pos = parse_vlq(msg, pos)
                if mid != 0:
                    continue
                off, pos = parse_vlq(msg, pos)
                ln, pos = parse_vlq(msg, pos)
                if off == offset:
                    got = msg[pos : pos + ln]
        if got is None:
            sys.exit("no identify_response at offset %d" % offset)
        data += got
        offset += len(got)
        if len(got) < 40:
            break
    os.close(fd)
    print(json.dumps(json.loads(zlib.decompress(data)), indent=1, sort_keys=True))


if __name__ == "__main__":
    main()
