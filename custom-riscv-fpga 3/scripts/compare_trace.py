#!/usr/bin/env python3
"""Compare every HDL retired instruction against independent RV32I interpreter.

Only TRACE lines are read; PASS/FATAL diagnostics from Icarus are left intact.
Compares PC, encoding, destination, value and all store side effects.
"""
import argparse
from pathlib import Path
from rv32i_ref import RV32I, load_image


def check(image: Path, tracefile: Path) -> int:
    lines = [line.strip() for line in tracefile.read_text().splitlines()
             if line.startswith("TRACE ")]
    if not lines:
        raise AssertionError("no retirement trace found")
    ref = RV32I(load_image(image))
    for i, line in enumerate(lines, 1):
        expected = ref.step().trace()
        if line != expected:
            raise AssertionError(f"instruction {i}:\nRTL {line}\nREF {expected}")
    print(f"PASS trace equality: {len(lines)} retired instructions ({image.name})")
    return len(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", type=Path, required=True)
    parser.add_argument("--trace", type=Path, required=True)
    args = parser.parse_args()
    check(args.image, args.trace)


if __name__ == "__main__":
    main()
