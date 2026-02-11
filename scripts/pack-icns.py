#!/usr/bin/env python3
import struct
import sys
from pathlib import Path


def chunk(type_code: bytes, payload: bytes) -> bytes:
    if len(type_code) != 4:
        raise ValueError("type_code must be 4 bytes")
    return type_code + struct.pack(">I", 8 + len(payload)) + payload


def main() -> int:
    if len(sys.argv) != 6:
        print(
            "Usage: pack-icns.py <128.png> <256.png> <512.png> <1024.png> <out.icns>",
            file=sys.stderr,
        )
        return 2

    p128, p256, p512, p1024, out = map(Path, sys.argv[1:])
    for p in (p128, p256, p512, p1024):
        if not p.is_file():
            print(f"Missing file: {p}", file=sys.stderr)
            return 1

    # Modern ICNS chunks that can contain PNG data:
    # - ic07: 128x128
    # - ic08: 256x256
    # - ic09: 512x512
    # - ic10: 1024x1024
    chunks = b"".join(
        [
            chunk(b"ic07", p128.read_bytes()),
            chunk(b"ic08", p256.read_bytes()),
            chunk(b"ic09", p512.read_bytes()),
            chunk(b"ic10", p1024.read_bytes()),
        ]
    )

    body = b"icns" + struct.pack(">I", 8 + len(chunks)) + chunks
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(body)
    print(f"Wrote: {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

