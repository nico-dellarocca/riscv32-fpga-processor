# Testing the CPU with Verilog

The main testbench is [`tb_soc.v`](tb_soc.v). It is meant to simulate the processor and the memory/LED circuit together.

With Icarus Verilog installed, run `make test` from the project root. The script will compile the Verilog, run three small programs, and compare each completed instruction with a Python reference interpreter. The tests also include programs that should stop because of invalid or misaligned instructions.

- [`sim/programs/isa.S`](programs/isa.S) checks arithmetic, jumps, branches, loads, and stores.
- [`software/smoke.c`](../software/smoke.c) checks a compiled C program with initialized variables and a success value.
- [`software/gpio_demo.c`](../software/gpio_demo.c) is intended to toggle the LED output.

The trace-comparison scripts are included but **their result with the real Verilog has not been verified here**. A C program passing in Python alone isn't proof of a working CPU. When you run this yourself, put the exact results in [MY_WORK.md](../MY_WORK.md).
