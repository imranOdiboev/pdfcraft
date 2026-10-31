"""Reject text errors, truncated PNGs and corrupt screenshot chunks."""
from pathlib import Path
import struct
import zlib

for name in ("home-en-light.png", "home-ru-dark.png", "tools-combine-en-light.png", "tools-split-en-light.png", "tools-reorder-ru-dark.png"):
    data = (Path("dist/android-emulator") / name).read_bytes()
    if len(data) < 5000 or not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError("Missing real PNG screenshot: " + name)
    offset = 8
    ended = False
    while offset + 12 <= len(data):
        size = struct.unpack_from(">I", data, offset)[0]
        kind = data[offset + 4:offset + 8]
        end = offset + 12 + size
        if end > len(data):
            raise ValueError("Truncated PNG: " + name)
        checksum = struct.unpack_from(">I", data, end - 4)[0]
        if zlib.crc32(data[offset + 4:end - 4]) != checksum:
            raise ValueError("PNG checksum mismatch: " + name)
        offset = end
        if kind == b"IEND":
            ended = True
            break
    if not ended or offset != len(data):
        raise ValueError("Incomplete PNG: " + name)
    print("Verified screenshot:", name)
