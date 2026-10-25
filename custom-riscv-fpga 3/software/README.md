# Programs for the small RISC-V CPU

This is *bare-metal* C: the programs don't use an operating system or the usual C standard library. Clang compiles them into 32-bit RISC-V instructions (`-march=rv32i -mabi=ilp32`).

- [`start.S`](start.S) sets up the stack, clears uninitialized variables, and calls `main`.
- [`linker.ld`](linker.ld) tells the compiler/linker where code and data fit in the 16 KB RAM.
- [`gpio_demo.c`](gpio_demo.c) is meant to flash LED0 by writing to a special memory address.
- [`smoke.c`](smoke.c) checks basic C arithmetic, the stack, memory, and GPIO. It writes `0x600D600D` to a test address if it gets the expected result.
- [`hello.c`](hello.c) is a small example kept from the starter.

Build the programs from the project root:

```sh
make -C software all
```

To inspect actual machine instructions, try:

```sh
make -C software disasm
```

The build generates `.hex` files with one 32-bit word per line; these are used to initialize the Verilog RAM. There is a shorter-loop version called `gpio_fast.hex` so the simulation doesn't need to wait through a long physical LED delay.

To run the programs in the **Python interpreter** (without using the Verilog):

```sh
make verify
```

To test them against the **Verilog CPU** (once Icarus is installed):

```sh
make test
```

Don't confuse the interpreter result with an FPGA demonstration. [See the exact test status](../docs/verification.md).
