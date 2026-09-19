#!/usr/bin/env python3
import hashlib, pathlib, sys
EXPECTED = "508dfc2d4caa42b6f6de5263d0aed5e44ac7966a"

def normalize(data: bytes) -> bytes:
    if data[:4] == bytes.fromhex("80371240"):
        return data
    if data[:4] == bytes.fromhex("37804012"):  # V64: swap adjacent bytes
        out = bytearray(data)
        out[0::2], out[1::2] = data[1::2], data[0::2]
        return bytes(out)
    if data[:4] == bytes.fromhex("40123780"):  # N64 little endian: reverse words
        out = bytearray(len(data))
        for i in range(0, len(data), 4):
            out[i:i+4] = data[i:i+4][::-1]
        return bytes(out)
    raise SystemExit("Unknown N64 ROM byte order")

if len(sys.argv) not in (2,3):
    raise SystemExit("usage: verify_rom.py input [normalized-output.z64]")
src = pathlib.Path(sys.argv[1])
data = normalize(src.read_bytes())
sha1 = hashlib.sha1(data).hexdigest()
print(f"normalized sha1: {sha1}")
if sha1 != EXPECTED:
    raise SystemExit(f"Wrong ROM revision. Expected {EXPECTED}")
if len(sys.argv) == 3:
    pathlib.Path(sys.argv[2]).write_bytes(data)
