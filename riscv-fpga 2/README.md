# RISC-V CPU on FPGA

## Why I built this

I already had a computer that could run my code, but I wanted to understand the machine underneath it. I was curious about how a processor actually follows instructions, uses memory, and runs a program. So I decided to try building one myself.

## The project

I built a simple 32-bit RISC-V CPU in Verilog, with a basic system around it. It includes:

- A non-pipelined CPU that supports 37 RISC-V instructions
- 16 KiB of memory for programs and data
- LED and button controls through memory-mapped I/O
- Assembly and C programs to test the CPU
- Testbenches to check instructions, memory, and other behavior

The design targets the Sipeed Tang Nano 20K FPGA board.

## Running the tests

With Make and Icarus Verilog installed, run:

```bash
make sim
```

To rebuild the firmware, you'll also need a RISC-V bare-metal GCC toolchain:

```bash
make firmware
```

The simulation tests and FPGA-targeted synthesis have passed, but I haven't verified the design on a physical FPGA yet.

## Files

- `rtl/` — CPU and FPGA design
- `sim/` — tests and sample programs
- `software/` — C code, startup code, and linker script
- `docs/` — design notes and test results

For more detail, see [design notes](docs/design_notes.md) and [testing results](docs/testing.md).

## What I learned

I learned how a CPU reads and decodes instructions, works with memory, and runs programs at the hardware level. Debugging the Verilog and writing tests also showed me how much work goes into getting even a simple processor to behave correctly. I mostly learned from YouTube videos and websites, and used AI occasionally when I got stuck.

## License

MIT — see [LICENSE](LICENSE).
