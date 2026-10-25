#!/usr/bin/env python3
"""Build and run the Icarus HDL regression, with per-retirement ISS comparison.

A missing simulator is a *hard failure*, never a pass or silent skip.
"""
from pathlib import Path
import shutil
import subprocess
import sys

from compare_trace import check

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/sim'
CASES = [
    ('isa', 'sim/build/programs/isa.hex', 'signature', None, 15000),
    ('compiled-c', 'software/build/smoke.hex', 'signature', None, 15000),
    ('gpio-compiled-c', 'software/build/gpio_fast.hex', 'gpio', None, 15000),
    ('illegal-opcode', 'sim/build/programs/illegal.hex', 'fault', 1, 100),
    ('unaligned-load', 'sim/build/programs/misaligned_load.hex', 'fault', 3, 100),
    ('unaligned-next-pc', 'sim/build/programs/misaligned_pc.hex', 'fault', 2, 100),
    ('ecall', 'sim/build/programs/ecall.hex', 'fault', 4, 100),
    ('ebreak', 'sim/build/programs/ebreak.hex', 'fault', 5, 100),
]


def execute(cmd):
    return subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True, check=True)


def main():
    for tool in ('iverilog', 'vvp'):
        if not shutil.which(tool):
            sys.exit(f"FAIL: {tool} is not installed. Install Icarus Verilog; "
                     "HDL verification has NOT been performed.")
    OUT.mkdir(parents=True, exist_ok=True)
    # Keep the original standalone blink/button tests in the regression.
    examples = [
        ('blink', 'tb_blink', ['examples/01_blink/blink.v', 'examples/01_blink/tb_blink.v']),
        ('button', 'tb_button_led', ['examples/02_button_led/button_led.v', 'examples/02_button_led/tb_button_led.v']),
        ('board-top', 'tb_top', [
            'rtl/cpu/rv32i_core.v', 'rtl/soc/rv32_soc.v',
            'rtl/top/tangnano20k_top.v', 'sim/tb_top.v']),
    ]
    tb = OUT / 'tb_soc.vvp'
    build = [
        'iverilog', '-g2012', '-Wall', '-s', 'tb_soc', '-o', str(tb),
        'rtl/cpu/rv32i_core.v', 'rtl/soc/rv32_soc.v', 'sim/tb_soc.v',
    ]
    print('Compiling hardware:', ' '.join(build), flush=True)
    try:
        result = execute(build)
        if result.stderr.strip():
            print(result.stderr, file=sys.stderr)
        for label, top, sources in examples:
            binary = OUT / f'{label}.vvp'
            res = execute(['iverilog', '-g2012', '-Wall', '-s', top, '-o', str(binary), *sources])
            if res.stderr.strip():
                print(res.stderr, file=sys.stderr)
            res = execute(['vvp', str(binary)])
            (OUT / f'{label}.log').write_text(res.stdout + res.stderr)
            if 'PASS' not in res.stdout:
                raise AssertionError(f'{label}: no simulator PASS marker')
            print(f'PASS HDL {label}: {res.stdout.strip().splitlines()[-1]}', flush=True)
        for label, image, scenario, reason, maxcycles in CASES:
            args = ['vvp', str(tb), f'+image={image}', f'+scenario={scenario}',
                    f'+max_cycles={maxcycles}']
            if reason is not None:
                args.append(f'+reason={reason}')
            result = execute(args)
            log = OUT / f'{label}.log'
            log.write_text(result.stdout + result.stderr)
            if 'PASS ' not in result.stdout:
                raise AssertionError(f'{label}: simulator did not report PASS')
            if scenario != 'fault':
                check(ROOT / image, log)
            print(f'PASS HDL {label}: {result.stdout.strip().splitlines()[-1]}', flush=True)
    except (subprocess.CalledProcessError, AssertionError) as err:
        if isinstance(err, subprocess.CalledProcessError):
            print(err.stdout, file=sys.stderr)
            print(err.stderr, file=sys.stderr)
        else:
            print(err, file=sys.stderr)
        sys.exit(1)
    print(f'PASS all {len(examples) + len(CASES)} HDL scenarios (including ISA trace checks)')


if __name__ == '__main__':
    main()
