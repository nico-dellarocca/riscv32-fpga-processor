#!/usr/bin/env python3
"""Reject instruction words outside this core's subset; input is ELF .text bytes.

The linker collects executable code in .text. Do not pass the complete firmware
binary: .rodata/.data contain arbitrary values that are not instructions. This
encoding check complements execution tests; it cannot prove program correctness.
"""
import argparse
from pathlib import Path


def supported(word):
    opcode = word & 0x7f
    funct3 = (word >> 12) & 7
    funct7 = word >> 25
    if opcode in (0x37, 0x17, 0x6f):       # LUI, AUIPC, JAL
        return True
    if opcode == 0x67:                    # JALR
        return funct3 == 0
    if opcode == 0x63:                    # Conditional branches
        return funct3 in (0, 1, 4, 5, 6, 7)
    if opcode == 0x03:                    # LB/LH/LW/LBU/LHU
        return funct3 in (0, 1, 2, 4, 5)
    if opcode == 0x23:                    # SB/SH/SW
        return funct3 in (0, 1, 2)
    if opcode == 0x13:                    # Integer immediate operations
        if funct3 == 1:
            return funct7 == 0            # SLLI
        if funct3 == 5:
            return funct7 in (0, 0x20)    # SRLI/SRAI
        return funct3 in (0, 2, 3, 4, 6, 7)
    if opcode == 0x33:                    # Integer register operations
        return funct7 == 0 or (funct7 == 0x20 and funct3 in (0, 5))
    return False                         # Includes SYSTEM, FENCE, M, C and CSR.


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("text_binary", type=Path)
    args = parser.parse_args()
    data = args.text_binary.read_bytes()
    if not data or len(data) % 4:
        parser.error(".text must contain a nonzero multiple of four bytes")
    rejected = []
    for offset in range(0, len(data), 4):
        word = int.from_bytes(data[offset:offset + 4], "little")
        if not supported(word):
            rejected.append(f".text+0x{offset:04x}: 0x{word:08x}")
    if rejected:
        parser.exit(1, "FAIL: unsupported instruction encoding(s)\n" + "\n".join(rejected) + "\n")
    print(f"PASS: {args.text_binary}: {len(data) // 4} encodings in implemented subset")


if __name__ == "__main__":
    main()
