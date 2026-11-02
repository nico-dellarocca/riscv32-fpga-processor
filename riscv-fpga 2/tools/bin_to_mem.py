#!/usr/bin/env python3
"""Convert little-endian bytes to 4096 readmemh words; pad unused RAM with zero."""
import argparse
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    data = args.input.read_bytes()
    if len(data) > 16384:
        parser.error(f"image is {len(data)} bytes; RAM holds 16384")
    data += bytes(16384 - len(data))
    words = (int.from_bytes(data[i:i + 4], "little") for i in range(0, 16384, 4))
    args.output.write_text("".join(f"{word:08x}\n" for word in words), encoding="ascii")
    print(f"WROTE {args.output}: 4096 words, zero-filled unused RAM")


if __name__ == "__main__":
    main()
