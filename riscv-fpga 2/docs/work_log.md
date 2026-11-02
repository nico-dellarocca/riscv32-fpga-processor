# Work Log 


### May 28, 2026 — Figuring out the scope

I'm going to try building a basic 32-bit RISC-V processor in Verilog for the Tang Nano 20K. The goal is to run assembly programs and eventually something compiled from C.

I'm keeping the CPU non-pipelined. A pipelined design would mean dealing with hazards and forwarding, and I'd rather get instruction execution and memory working first.

I'm planning on using 32 registers, a simple ALU, and a single block of RAM shared by instructions and data. I'll focus on the basic integer instructions and leave multiplication, division, compressed instructions, and privileged features out of scope.

I want to get everything working in simulation before trying the FPGA.

### June 4, 2026 — Register file and instruction decoding

Working on `rv32i_core.v`.

The register file has 32 registers, each 32 bits wide. Register `x0` is a special case because it's supposed to stay zero even if an instruction tries to write to it. I'm handling that in both the read and write logic.

I also added the fields needed to decode an instruction: opcode, destination register, source registers, `funct3`, and `funct7`.

Something I need to be careful about is making sure instructions only write to registers when they're supposed to. Stores and branches shouldn't accidentally change anything in the register file.

Next is getting the immediate values and ALU operations working.

### June 9, 2026 — ALU and immediate formats

Added the integer arithmetic, logical operations, shifts, and comparisons.

One part that needs special attention is signed versus unsigned comparisons. `0xFFFFFFFF` is -1 when signed, but the largest possible 32-bit unsigned number. `SLT` and `SLTU` need to handle that difference.

The immediate formats are also more complicated than I initially expected. For branches and jumps, the immediate bits aren't all next to each other. They have to be put back together in the correct order and sign-extended.

Negative branch offsets are something I want to check carefully. I'll include those cases in the instruction tests.

### June 13, 2026 — CPU state machine

I've settled on using three states: `FETCH`, `EXEC`, and `LOAD_WB`.

The main issue is RAM timing. The memory has a registered read output, so the data doesn't appear immediately when the CPU requests it.

In this design, normal instructions take three clock cycles. Loads need another cycle because the register writeback has to happen after the RAM data becomes available.

This makes the processor slower than a pipelined design, but it's easier to follow what happens on each clock edge.

I want the testbench to check the actual cycle counts. Otherwise, the CPU could appear to work while handling memory timing incorrectly.

### June 17, 2026 — Connecting RAM

Set up a 16 KiB RAM with 4,096 32-bit words.

The CPU uses the same memory for instructions and data. I'm keeping the memory interface fairly simple, with addresses, read and write data, request signals, and byte-write enables.

The byte enables are important because byte and halfword stores shouldn't overwrite the entire 32-bit word.

The system is little-endian, so I need to make sure the byte selection and data shifting agree with that layout.

### June 23, 2026 — Load and store instructions

Working on the different memory access widths.

The CPU needs to support `LB`, `LBU`, `LH`, `LHU`, `LW`, `SB`, `SH`, and `SW`.

A byte store should change only one byte, and a halfword store should change only two. The remaining bytes have to stay the same.

Loads also need to select the correct part of the word and either sign-extend or zero-extend it.

A useful test case is loading `0x80` as a signed byte versus an unsigned byte. `LB` should return `0xFFFFFF80`, while `LBU` should return `0x00000080`.

I want the memory tests to cover these cases rather than just checking 32-bit loads and stores.

### June 27, 2026 — Handling invalid operations

Added checks for unsupported instructions, bad memory addresses, and misaligned accesses.

Word accesses have to be on four-byte boundaries, and halfword accesses have to be on two-byte boundaries.

When something invalid happens, the CPU records a fault code and the address of the instruction that caused it. It then stays halted until reset.

One thing I need to make sure of is that a rejected store doesn't still update memory. Reporting a fault isn't enough if the invalid operation already changed something.

The tests should check both the fault outputs and whether memory or I/O was modified.

### July 2, 2026 — Connecting the SoC

Working on `rv32_soc.v`, which connects the processor, RAM, and I/O registers.

The LED is controlled through a memory-mapped register at `0x10000000`. The button is read at `0x10000004`.

That means the CPU doesn't need special instructions to interact with the board. It can use ordinary loads and stores.

I also added a simulation-only completion register at `0x10000010`. A test program can write a result there so the testbench knows when it's finished.

The completion register won't be available in the hardware configuration.

I need to make sure peripheral addresses don't accidentally overlap with regular RAM.

### July 9, 2026 — FPGA top-level module

Added `tangnano20k_top.v` and the board pin constraints.

The board's LED is active-low, so the signal from the SoC has to be inverted at the top level. Otherwise writing a logical 1 to turn on the LED would produce the wrong physical output.

The button goes through two flip-flops to synchronize it to the clock. I also included a power-up reset counter.

I haven't tested the actual board yet. The pin assignments come from the board documentation, and the reset and button behavior still need physical verification.

There's also no button debouncing implemented. That might matter if I use it for anything that depends on individual button presses.

### July 17, 2026 — Assembly test programs

Added some small programs to test the CPU through the full SoC.

I have separate programs for arithmetic, memory accesses, and branches. The branch program covers backward jumps as well as forward branches, since negative offsets are one of the cases I want to verify.

There's also an LED program that writes to the memory-mapped register and reads the button input.

These tests are useful because they run actual instructions from RAM instead of driving the CPU signals directly.

I also included a hardware-oriented LED program with delay loops for when I get to testing on the board.

### July 23, 2026 — Getting C to run

Working on running a small C program on the CPU.

Since there's no operating system, I need startup assembly and a linker script. The startup code sets the stack pointer, initializes the global pointer, clears `.bss`, and calls `main()`.

The RAM is only 16 KiB, so I reserved 1 KiB near the top for the stack. The linker script checks that the program's static sections don't overlap that space.

The C program needs to test more than simple arithmetic. I want to check globals, function calls, stack accesses, and different memory operations.

### July 29, 2026 — C smoke test

The C test program checks initialized and zero-initialized globals, function calls, stack use, a local array, and byte/halfword accesses. It also uses the LED register.

One useful testbench detail is filling `.bss` with nonzero data before startup.

That should make it possible to catch missing `.bss` initialization rather than accidentally passing because RAM happens to start at zero.

The testing records include a successful 433-cycle C run, although the available evidence does not establish that the run occurred on this date.

### August 4, 2026 — Firmware build scripts

Set up the build process for assembly and C programs.

I'm compiling for RV32I with the ILP32 ABI. I added `check_isa.py` because I don't want the compiler output to contain instructions that the processor doesn't support.

`bin_to_mem.py` converts the compiled binary into a memory initialization file containing 4,096 words.

The important thing is that the exact compiled image used in simulation should be reproducible. Otherwise, it becomes difficult to tell whether a test result corresponds to the source code I currently have.

### August 7, 2026 — Toolchain setup problems

The project records several issues with the development tools rather than with the processor RTL.

Icarus Verilog had trouble creating a temporary file under `/tmp`. Using a writable temporary directory resolved that problem.

The RISC-V compiler installation was also missing `liblto_plugin.so`, which prevented the firmware build from proceeding normally.

These are recorded problems, but I don't have the original command transcripts establishing that they happened on August 7. The commands and corrections are documented in the later validation record.

### August 13, 2026 — Linker-script issue

The build records include a linker problem involving an unplaced `.rela.text.start` section.

The linker script needed to account for relocation metadata while still preventing unsupported runtime relocations.

After the correction, the recorded firmware build completed.

This is useful to keep separate from CPU debugging because a linker failure happens before the program even runs on the processor.

The exact date of the original failure isn't established by the preserved tool output.

### August 24, 2026 — CPU and SoC verification

The CPU testbench, `sim/tb_cpu.v`, covers the implemented instructions, branches, jumps, register behavior, load/store operations, and fault handling.

It also checks the expected instruction-cycle counts.

The SoC testbench, `sim/tb_soc.v`, goes further by running the compiled assembly and C programs through the complete CPU, RAM, and peripheral system.

I'm treating these as directed tests of the implemented instruction subset. They aren't a complete independent RISC-V conformance test.

The preserved passing results are from the later recorded validation session.

### August 28, 2026 — Improving the LED test

The GPIO test review identified a gap in what was being checked.

The earlier test covered the write requests and the final LED state, but that wasn't enough to verify every intermediate LED output.

The monitor was updated to check the actual LED value after each accepted write.

This was a verification improvement. The recorded results don't establish that there was an actual bug in the LED logic.

The revised test passes in the preserved validation results.

### September 5, 2026 — FPGA wrapper and blinking example

The project includes `sim/tb_top.v`, which checks the reset sequence, button synchronization, active-low LED output, and the absence of the simulation completion register in hardware mode.

There's also a smaller blinking-counter design with its own testbench.

The idea is to have something simpler to try on the board before moving to the full processor.

The recorded tests pass, but this is still simulation. It doesn't establish whether the actual pins or reset behavior work on the Tang Nano 20K.

### September 23, 2026 — Synthesis

The synthesis setup targets the Gowin GW2A family using Yosys.

The design needs the RAM to map to FPGA block memory rather than being implemented as thousands of ordinary registers.

The saved synthesis report shows the 16 KiB memory mapped to eight single-port block-memory primitives, covering 131,072 bits.

The final structural check also reports zero problems.

The successful recorded run used Yosys 0.70 because an older version didn't support the required GW2A synthesis option.

I still need placement, routing, and timing analysis before drawing conclusions about the physical implementation.

### October 1, 2026 — Current status and remaining work

The project now has the CPU, SoC, assembly programs, C runtime files, and simulation infrastructure.

The major remaining task is running the design on the actual FPGA.

I need to complete placement and routing, check timing against the board's 27 MHz clock, generate a bitstream, and program the Tang Nano 20K.

After that I'll need to check the LED, button, reset behavior, and whether the processor reliably starts running its firmware.

I also want to expand testing beyond the current directed instruction tests.

The project shouldn't be described as physically FPGA-tested until those steps are completed.

### October 19, 2026 — Recorded build and simulation results

The retained testing record documents execution of the CPU and SoC simulations, firmware builds, and top-level tests on this date.

All four Verilog testbenches completed successfully: `tb_blink`, `tb_cpu`, `tb_soc`, and `tb_top`.

The CPU arithmetic test finished in 96 counted clock cycles. The memory test took 89, including the additional cycles for loads.

The assembly programs completed with the expected results, and the C smoke test completed in 433 cycles.

The recorded SoC completion counts were:

| Program | Clock cycles |
|---|---:|
| Arithmetic | 60 |
| Memory | 108 |
| Branch | 90 |
| LED | 73 |
| C smoke test | 433 |

The firmware build produced seven ELF variants and checked the emitted instructions against the supported subset.

The recorded Yosys synthesis also completed, with eight inferred RAM primitives and zero problems in the final structural check.

There were warnings during RAM mapping, so the mapped cells were inspected to confirm their active data inputs were connected. The other input bits were unused padding for the selected memory configuration.

The results support correct behavior for the tested programs and successful synthesis. Physical FPGA operation remains unverified.

### Next steps

The next milestone is getting the design onto the Tang Nano 20K.

I still need to complete the FPGA tool flow, check timing, program the board, and verify the peripherals on actual hardware.

The current tests cover the implemented instruction subset and several fault conditions, but broader ISA verification would make the results stronger.

Once there are real board results, I can compare the physical behavior with the simulation results and investigate any differences.
