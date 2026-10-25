"""Verify trace checker behavior without assuming a Verilog simulator exists."""
from pathlib import Path
from tempfile import TemporaryDirectory
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
from compare_trace import check
from rv32i_ref import RV32I, load_image


class TraceComparatorTests(unittest.TestCase):
    def test_reference_trace_is_accepted(self):
        image = ROOT / 'software/build/smoke.hex'
        cpu = RV32I(load_image(image))
        events, _ = cpu.run(1000, 'signature')
        with TemporaryDirectory() as folder:
            log = Path(folder) / 'trace.log'
            log.write_text('\n'.join(e.trace() for e in events) + '\n')
            self.assertEqual(check(image, log), len(events))

    def test_corrupt_writeback_is_rejected(self):
        image = ROOT / 'software/build/smoke.hex'
        cpu = RV32I(load_image(image))
        events, _ = cpu.run(1000, 'signature')
        lines = [e.trace() for e in events]
        line = lines[15].split()
        line[4] = 'ffffffff'  # replace destination value
        lines[15] = ' '.join(line)
        with TemporaryDirectory() as folder:
            log = Path(folder) / 'trace.log'
            log.write_text('\n'.join(lines) + '\n')
            with self.assertRaisesRegex(AssertionError, 'instruction 16'):
                check(image, log)

    def test_empty_trace_rejected(self):
        with TemporaryDirectory() as folder:
            log = Path(folder) / 'trace.log'
            log.write_text('PASS but no retirement events\n')
            with self.assertRaisesRegex(AssertionError, 'no retirement trace'):
                check(ROOT / 'software/build/smoke.hex', log)
