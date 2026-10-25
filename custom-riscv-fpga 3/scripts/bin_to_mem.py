#!/usr/bin/env python3
"""Convert raw RV32I little-endian bytes to $readmemh 32-bit words.

Each output line is a single 8-digit hex *word* in instruction order.
If a binary starts with bytes [0x93, 0x00, 0xa0, 0x00], the first word
is 00a00093 (RISC-V ADDI x1,x0,10), because memory is little endian.

Assumes a unified memory image starting at address zero.
"""
import argparse
from pathlib import Path


def convert(data: bytes, size_bytes: int) -> str:
    if size_bytes <= 0 or size_bytes % 4:
        raise ValueError("memory capacity must be positive and divisible by four")
    if len(data) > size_bytes:
        raise ValueError(f"image is {len(data)} bytes; RAM capacity is {size_bytes}")
    padded = data + bytes(size_bytes - len(data))
    return "".join(
        f"{int.from_bytes(padded[i:i + 4], 'little'):08x}\n"
        for i in range(0, size_bytes, 4)
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--size-bytes", type=int, default=16384)
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(convert(args.input.read_bytes(), args.size_bytes))
    print(f"Wrote {args.output} ({args.size_bytes // 4} 32-bit words)")


if __name__ == "__main__":
    main()
