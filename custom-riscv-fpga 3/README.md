# RISC-V CPU on a Tang Nano 20K

*A small FPGA computer project — still in progress.*

The idea is to get a processor written in Verilog to run a tiny C program and control an LED on the Tang Nano 20K board. The processor uses the basic 32-bit RISC-V integer instructions (RV32I). There is no operating system, and it is deliberately much simpler than a desktop CPU.

The project began with an FPGA LED-blink exercise. The newer processor, memory system, and test code were added as an **AI-assisted starting point**; they still need to be checked in an HDL simulator and on the actual FPGA. See [AI_ASSISTANCE.md](AI_ASSISTANCE.md) and [MY_WORK.md](MY_WORK.md) for how to document personal contributions.

## Where it stands

| Part | Status |
| --- | --- |
| Basic LED-blink example | Earlier build and SRAM programming reported in the original project notes |
| RV32I CPU and memory/LED connections | Source code written; hardware behavior not yet confirmed |
| C and assembly test programs | Compile and run in the Python reference model |
| Verilog CPU simulation | Testbench included; **not yet run successfully in this package** |
| CPU running on the FPGA | **Not demonstrated yet** |

Those last two steps matter most. A reference model running a C program does **not** prove that the Verilog CPU works. [Details of which tests have actually run](docs/verification.md).

## What the computer looks like

```text
    C program
        |
   Clang compiler
        |
  RISC-V instructions
        |
   +------------+
   | Verilog CPU|  fetch -> execute -> load result
   +------------+
        |
   +----+---------+
   |              |
  16 KB RAM     LED output
```

The CPU has 32 registers (`x0` is always zero), a program counter, an instruction decoder, and arithmetic/branch logic. It uses three steps: fetch an instruction, execute it, and take an extra step for loads. The RAM holds both the program and its data. A write to address `0x10000000` changes the LED output.

The implementation is in [`rtl/cpu/rv32i_core.v`](rtl/cpu/rv32i_core.v) and [`rtl/soc/rv32_soc.v`](rtl/soc/rv32_soc.v). The explanation in [docs/architecture.md](docs/architecture.md) includes the choices and current limits.

## Try it

You'll need **Python 3**, **Make**, **Clang with RISC-V support**, and **llvm-objcopy**. From this folder:

```sh
make verify
```

This builds the C/assembly programs, runs Python unit tests, and checks their results in a separate RISC-V interpreter. It does **not** run the Verilog.

Next, install **Icarus Verilog** (`iverilog` and `vvp`) and run:

```sh
make test
```

That command also simulates the Verilog CPU and compares the instructions it executes with the interpreter's results. It deliberately fails if the simulator is missing. `make check` runs both the repository file checks and all tests.

The FPGA part needs the Tang Nano 20K and a working Gowin-compatible toolchain:

```sh
make soc           # synthesize and build a bitstream
make program-soc   # load it onto a connected FPGA
```

Neither command has been verified for this CPU design in this package. Check the board pin assignments before trying them. There are setup notes in [docs/build-and-tools.md](docs/build-and-tools.md).

## Files I would start with

| File/folder | What it does |
| --- | --- |
| [`examples/01_blink`](examples/01_blink/README.md) | Original simple LED example — good place to learn Verilog |
| [`rtl/cpu/rv32i_core.v`](rtl/cpu/rv32i_core.v) | Instruction decoder, registers, and CPU state machine |
| [`rtl/soc/rv32_soc.v`](rtl/soc/rv32_soc.v) | RAM and memory-mapped LED/button registers |
| [`software/gpio_demo.c`](software/gpio_demo.c) | A C program intended to blink the LED through the CPU |
| [`sim/tb_soc.v`](sim/tb_soc.v) | Testbench for the CPU and memory system |
| [`docs/verification.md`](docs/verification.md) | What was tested and what is still unknown |
| [`MY_WORK.md`](MY_WORK.md) | A place to record real changes, bugs, and results |

## Next steps

1. Run `make test` on a machine with Icarus Verilog. Fix any failures and save the logs.
2. Understand at least one instruction end to end (for example, `ADDI` or `SW`). Write down how it changes the registers or memory.
3. Get the CPU design to build for the FPGA and check the timing and resource reports.
4. Load it onto the board and record a real LED demonstration if it works.

The aim is a small working CPU that its builder can explain clearly. The repository keeps the more advanced testing scripts available, but those scripts are supporting tools, not evidence of physical hardware operation.

**Credits and scope:** The original FPGA bring-up materials came from the supplied starter project. The expanded CPU, SoC, firmware and test framework were produced with substantial ChatGPT assistance; see [AI_ASSISTANCE.md](AI_ASSISTANCE.md). Use [MY_WORK.md](MY_WORK.md) to distinguish work personally completed afterward. The repository uses the [MIT license](LICENSE).
