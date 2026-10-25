# How the CPU is put together

The goal is to understand the path from a machine instruction to a change in a register or memory. The main files are [`rv32i_core.v`](../rtl/cpu/rv32i_core.v) (CPU) and [`rv32_soc.v`](../rtl/soc/rv32_soc.v) (RAM and LED/button addresses).

## 1. What the CPU keeps track of

- **Program counter (`pc`):** the address of the next instruction.
- **32 registers (`x0` to `x31`):** numbers used by instructions. `x0` always reads as zero.
- **Instruction decoder:** looks at bits in the instruction to choose an operation.
- **ALU:** adds, subtracts, shifts, and compares numbers.
- **Memory interface:** reads and writes the 16 KB RAM or the small GPIO registers.

For example, `addi x5, x0, 7` means *put 7 in register x5*. A store instruction can then write a value to the LED's memory-mapped address, `0x10000000`.

## 2. Why it takes more than one clock cycle

The RAM in this design has a **registered output**: when the CPU asks for a memory word, the word becomes available after a clock edge. That is one reason a very simple single-cycle CPU is awkward for this FPGA design.

This version uses three states:

| State | What happens |
| --- | --- |
| `FETCH` | Ask memory for the instruction at `pc`. |
| `EXEC` | Decode and execute it. Arithmetic, branches, and stores can finish here. |
| `LOAD_WB` | Finish a load by putting the memory result into the destination register. |

Normal instructions use two cycles and loads use three. There is no pipelining, branch prediction, or instruction cache.

## 3. Where the program lives

The SoC has one 16 KB area of RAM for program instructions, program data, and stack. The compiled program is converted into a text file of hex words that the Verilog memory can load with `$readmemh`.

Two addresses are handled differently:

- `0x10000000` — the output register connected to LED0 (the physical LED is active-low).
- `0x10000004` — button input (the physical pin assignment is not verified yet).

There is also a write-only `0x10000010` address for a test program to report success in simulation; it is not a UART. The full address map is in [memory-map.md](memory-map.md).

## 4. Instructions and limits

The Verilog source attempts the base **RV32I integer instructions**: loads/stores, branches/jumps, arithmetic, shifts, comparisons, and upper immediates. It supports byte, halfword, and word loads/stores with aligned addresses.

It does **not** implement multiplication/division (`M`), compressed instructions (`C`), floating point, interrupts, privilege levels, CSRs, or exception handlers. Illegal instructions, misaligned accesses, `ECALL`, and `EBREAK` stop the CPU with a diagnostic code rather than being handled like a full computer would handle them.

The extra `trace_*` signals in the CPU report the instruction address, instruction bits, destination register, and writes to memory. The testbench uses these to compare the Verilog CPU with a separate Python model. That comparison **has not been run successfully in the package preparation environment**.

## 5. What still needs checking

The code and testbench exist, but a correct-looking design can still fail in simulation or when it is put on an FPGA. In particular, the 16 KB RAM has to map correctly onto Gowin FPGA resources, the design must meet timing, and the button pin may need correcting and synchronization.

The next experiment should be to run `make test`, inspect the first mismatch (if any), and then try `make soc`. None of these hardware results should be assumed before running the tools.

Reference: [RISC-V RV32I specification](https://docs.riscv.org/reference/isa/v20260120/unpriv/rv32.html).
