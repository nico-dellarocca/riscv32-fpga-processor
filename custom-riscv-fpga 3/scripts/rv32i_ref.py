#!/usr/bin/env python3
"""Independent RV32I instruction interpreter used as a trace oracle.

Architecture-level model, not an HDL simulation. The 16 KiB RAM and MMIO map
follow rtl/soc/rv32_soc.v. This implementation deliberately uses bytearray
loads/stores instead of the CPU RTL's 32-bit strobes.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path

MASK = 0xFFFFFFFF
RAM_BYTES = 16384
PASS = 0x600D600D
FAIL = 0xDEADBEEF


def u32(value: int) -> int:
    return value & MASK


def signed(value: int, bits: int = 32) -> int:
    value &= (1 << bits) - 1
    return value - (1 << bits) if value & (1 << (bits - 1)) else value


def load_image(path: Path) -> bytes:
    words = [int(s, 16) for s in path.read_text().splitlines()]
    if len(words) != RAM_BYTES // 4:
        raise ValueError(f"{path}: expected {RAM_BYTES // 4} words; got {len(words)}")
    return b"".join(w.to_bytes(4, "little") for w in words)


class Stop(Exception):
    def __init__(self, reason: int, pc: int):
        self.reason, self.pc = reason, pc
        super().__init__(f"stop reason={reason} pc=0x{pc:08x}")


@dataclass(frozen=True)
class Retired:
    pc: int
    insn: int
    rd: int
    value: int
    store_mask: int
    store_addr: int
    store_data: int

    def trace(self) -> str:
        return (f"TRACE {self.pc:08x} {self.insn:08x} {self.rd:02x} "
                f"{self.value:08x} {self.store_mask:x} {self.store_addr:08x} "
                f"{self.store_data:08x}")


class RV32I:
    def __init__(self, initial: bytes, button_pressed: bool = False):
        if len(initial) > RAM_BYTES:
            raise ValueError("firmware image larger than RAM")
        self.memory = bytearray(initial.ljust(RAM_BYTES, b"\x00"))
        self.regs = [0] * 32
        self.pc = 0
        self.gpio = 0
        self.test_code = None
        self.button_pressed = button_pressed
        self.retired = 0

    def read(self, address: int, size: int) -> int:
        if 0 <= address <= RAM_BYTES - size:
            return int.from_bytes(self.memory[address:address + size], "little")
        if 0x10000000 <= address <= 0x10000003:
            return (self.gpio >> (8 * (address % 4))) & ((1 << (size * 8)) - 1)
        if 0x10000004 <= address <= 0x10000007:
            return int(self.button_pressed) >> (8 * (address % 4))
        return 0

    def write(self, address: int, size: int, value: int) -> None:
        value &= (1 << (8 * size)) - 1
        if 0 <= address <= RAM_BYTES - size:
            self.memory[address:address + size] = value.to_bytes(size, "little")
        elif 0x10000000 <= address <= 0x10000003:
            mask = ((1 << (8 * size)) - 1) << (8 * (address % 4))
            self.gpio = u32((self.gpio & ~mask) | (value << (8 * (address % 4))))
        elif address == 0x10000010 and size == 4:
            self.test_code = value

    def step(self) -> Retired:
        pc = self.pc
        if pc & 3:
            raise Stop(2, pc)
        insn = self.read(pc, 4)
        op = insn & 0x7F
        rd = (insn >> 7) & 31
        f3 = (insn >> 12) & 7
        rs1 = (insn >> 15) & 31
        rs2 = (insn >> 20) & 31
        f7 = insn >> 25
        a, b = self.regs[rs1], self.regs[rs2]
        imm_i = signed(insn >> 20, 12)
        imm_s = signed(((insn >> 25) << 5) | ((insn >> 7) & 31), 12)
        imm_b = signed((((insn >> 31) & 1) << 12) |
                       (((insn >> 7) & 1) << 11) |
                       (((insn >> 25) & 63) << 5) |
                       (((insn >> 8) & 15) << 1), 13)
        imm_u = insn & 0xFFFFF000
        imm_j = signed((((insn >> 31) & 1) << 20) |
                       (((insn >> 12) & 255) << 12) |
                       (((insn >> 20) & 1) << 11) |
                       (((insn >> 21) & 1023) << 1), 21)
        next_pc = u32(pc + 4)
        value = 0
        write_rd = False
        store_mask = store_addr = store_data = 0

        if op == 0x37:  # LUI
            value, write_rd = imm_u, True
        elif op == 0x17:  # AUIPC
            value, write_rd = u32(pc + imm_u), True
        elif op == 0x6F:  # JAL
            value, write_rd = u32(pc + 4), True
            next_pc = u32(pc + imm_j)
        elif op == 0x67 and f3 == 0:  # JALR
            value, write_rd = u32(pc + 4), True
            next_pc = u32(a + imm_i) & ~1
        elif op == 0x63:  # BRANCH
            conditions = {
                0: a == b, 1: a != b,
                4: signed(a) < signed(b), 5: signed(a) >= signed(b),
                6: a < b, 7: a >= b,
            }
            if f3 not in conditions:
                raise Stop(1, pc)
            if conditions[f3]:
                next_pc = u32(pc + imm_b)
        elif op in (0x03, 0x23):  # LOAD/STORE
            address = u32(a + (imm_i if op == 0x03 else imm_s))
            sizes = {0: 1, 1: 2, 2: 4, 4: 1, 5: 2} if op == 0x03 else {0: 1, 1: 2, 2: 4}
            if f3 not in sizes:
                raise Stop(1, pc)
            size = sizes[f3]
            if address % size:
                raise Stop(3, pc)
            if op == 0x03:
                value = self.read(address, size)
                if f3 in (0, 1):
                    value = u32(signed(value, 8 * size))
                write_rd = True
            else:
                self.write(address, size, b)
                store_addr = address
                store_mask = ((1 << size) - 1) << (address % 4)
                store_data = u32(b << (8 * (address % 4)))
        elif op == 0x13:  # OP-IMM
            write_rd = True
            if f3 == 0: value = u32(a + imm_i)
            elif f3 == 2: value = int(signed(a) < imm_i)
            elif f3 == 3: value = int(a < u32(imm_i))
            elif f3 == 4: value = u32(a ^ imm_i)
            elif f3 == 6: value = u32(a | imm_i)
            elif f3 == 7: value = u32(a & imm_i)
            elif f3 == 1 and f7 == 0: value = u32(a << rs2)
            elif f3 == 5 and f7 == 0: value = a >> rs2
            elif f3 == 5 and f7 == 0x20: value = u32(signed(a) >> rs2)
            else: raise Stop(1, pc)
        elif op == 0x33:  # OP
            write_rd = True
            functions = {
                (0, 0): lambda: a + b,
                (0x20, 0): lambda: a - b,
                (0, 1): lambda: a << (b & 31),
                (0, 2): lambda: int(signed(a) < signed(b)),
                (0, 3): lambda: int(a < b),
                (0, 4): lambda: a ^ b,
                (0, 5): lambda: a >> (b & 31),
                (0x20, 5): lambda: signed(a) >> (b & 31),
                (0, 6): lambda: a | b,
                (0, 7): lambda: a & b,
            }
            if (f7, f3) not in functions:
                raise Stop(1, pc)
            value = u32(functions[f7, f3]())
        elif op == 0x0F and f3 == 0 and rd == rs1 == 0:  # FENCE
            pass
        elif insn == 0x00000073:
            raise Stop(4, pc)
        elif insn == 0x00100073:
            raise Stop(5, pc)
        else:
            raise Stop(1, pc)

        if next_pc & 3:
            raise Stop(2, pc)
        effective_rd = rd if write_rd and rd != 0 else 0
        if effective_rd:
            self.regs[rd] = u32(value)
        self.pc = next_pc
        self.retired += 1
        return Retired(pc, insn, effective_rd,
                       self.regs[effective_rd] if effective_rd else 0,
                       store_mask, store_addr, store_data)

    def run(self, steps: int, mode: str) -> tuple[list[Retired], str]:
        events: list[Retired] = []
        last_gpio = self.gpio & 1
        toggles = 0
        for _ in range(steps):
            events.append(self.step())
            if self.test_code is not None:
                if self.test_code != PASS:
                    raise AssertionError(f"failure signature: 0x{self.test_code:08x}")
                return events, f"PASS signature=0x{self.test_code:08x} instructions={self.retired}"
            current = self.gpio & 1
            if current != last_gpio:
                toggles += 1
                last_gpio = current
            if mode == "gpio" and toggles >= 4:
                return events, f"PASS gpio_transitions={toggles} instructions={self.retired}"
        raise AssertionError(f"run exceeded {steps} instructions: mode={mode}, pc={self.pc:08x}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", type=Path, required=True)
    parser.add_argument("--mode", choices=["signature", "gpio", "steps"], default="signature")
    parser.add_argument("--steps", type=int, default=20000)
    parser.add_argument("--trace-output", type=Path)
    args = parser.parse_args()
    cpu = RV32I(load_image(args.image))
    if args.mode == "steps":
        events = [cpu.step() for _ in range(args.steps)]
        status = f"PASS steps={args.steps}"
    else:
        events, status = cpu.run(args.steps, args.mode)
    if args.trace_output:
        args.trace_output.parent.mkdir(parents=True, exist_ok=True)
        args.trace_output.write_text("\n".join(e.trace() for e in events) + "\n")
    print(f"REFERENCE MODEL: {status} ({args.image})")


if __name__ == "__main__":
    main()
