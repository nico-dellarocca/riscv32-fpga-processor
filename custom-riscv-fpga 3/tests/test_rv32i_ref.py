"""Standalone checks of the reference ISA interpreter and compiled binaries."""
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
from rv32i_ref import RV32I, Stop, load_image, PASS


def single_insn(word):
    return RV32I(word.to_bytes(4, 'little') + b'\x13\x00\x00\x00')


class RV32IReferenceTests(unittest.TestCase):
    def test_x0_is_hardwired(self):
        cpu = single_insn(0x07b00013)  # addi x0,x0,123
        result = cpu.step()
        self.assertEqual((cpu.regs[0], result.rd, result.value, cpu.pc), (0, 0, 0, 4))

    def test_signed_addi_and_overflow(self):
        cpu = single_insn(0xfff08093)  # addi x1,x1,-1
        cpu.step()
        self.assertEqual(cpu.regs[1], 0xFFFFFFFF)
        cpu.pc = 0
        cpu.step()
        self.assertEqual(cpu.regs[1], 0xFFFFFFFE)

    def test_misaligned_load(self):
        cpu = single_insn(0x00102283)  # lw x5,1(x0)
        with self.assertRaises(Stop) as ctx:
            cpu.step()
        self.assertEqual(ctx.exception.reason, 3)

    def test_unsupported_mul(self):
        cpu = single_insn(0x021080b3)  # mul x1,x1,x1 (M extension)
        with self.assertRaises(Stop) as ctx:
            cpu.step()
        self.assertEqual(ctx.exception.reason, 1)

    def test_ebreak(self):
        with self.assertRaises(Stop) as ctx:
            single_insn(0x00100073).step()
        self.assertEqual(ctx.exception.reason, 5)

    def test_program_images_exist_and_fit(self):
        for name in ('smoke', 'gpio_fast'):
            path = ROOT / 'software' / 'build' / f'{name}.hex'
            self.assertEqual(len(load_image(path)), 16384)

    def test_c_smoke_passes_reference(self):
        cpu = RV32I(load_image(ROOT / 'software/build/smoke.hex'))
        events, status = cpu.run(3000, 'signature')
        self.assertEqual(cpu.test_code, PASS)
        self.assertEqual(cpu.gpio & 1, 1)
        self.assertGreater(len(events), 25)
        self.assertIn('PASS', status)

    def test_isa_passes_reference(self):
        cpu = RV32I(load_image(ROOT / 'sim/build/programs/isa.hex'))
        events, _ = cpu.run(3000, 'signature')
        self.assertEqual(cpu.test_code, PASS)
        self.assertGreater(len(events), 80)

    def test_gpio_firmware_toggles(self):
        cpu = RV32I(load_image(ROOT / 'software/build/gpio_fast.hex'))
        events, status = cpu.run(6000, 'gpio')
        self.assertIn('gpio_transitions=4', status)
        self.assertGreater(len(events), 60)

    def test_fault_images(self):
        reasons = {'illegal': 1, 'misaligned_load': 3, 'misaligned_pc': 2,
                   'ecall': 4, 'ebreak': 5}
        for stem, expected in reasons.items():
            with self.subTest(stem=stem):
                cpu = RV32I(load_image(ROOT / f'sim/build/programs/{stem}.hex'))
                with self.assertRaises(Stop) as ctx:
                    cpu.step()
                self.assertEqual(ctx.exception.reason, expected)
                self.assertEqual(ctx.exception.pc, 0)


if __name__ == '__main__':
    unittest.main()
