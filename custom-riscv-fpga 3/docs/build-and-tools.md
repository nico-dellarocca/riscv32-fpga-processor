# Running the code and trying the FPGA

You can do the first checks without a board. The physical Tang Nano 20K comes later.

## Software checks (no FPGA needed)

Install Python 3, Make, Clang with support for the `riscv32-unknown-elf` target, and `llvm-objcopy`.

```sh
make verify
```

The build compiles the C files to 32-bit RISC-V instructions, then converts the program into hex words suitable for the Verilog RAM. `make verify` runs the resulting programs in a Python reference interpreter.

## Verilog simulation (still no FPGA needed)

Install [Icarus Verilog](https://steveicarus.github.io/iverilog/) to get `iverilog` and `vvp`.

```sh
make test
```

This simulates the actual Verilog CPU and compares its instruction results against the interpreter. It is an essential next check and **was not successfully run when this package was prepared**.

## Building for the Tang Nano 20K

This step needs Gowin-compatible tools: Yosys (`synth_gowin`), nextpnr-himbaechel, `gowin_pack`, and openFPGALoader. The [YosysHQ OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build) is one way to install them. Start with `make tools` to see what your terminal can find.

```sh
make soc
make program-soc
```

`make soc` attempts to create the FPGA bitstream. `make program-soc` loads it to volatile SRAM on a connected Tang Nano 20K. You need a USB data cable and the correct driver setup.

The supplied top module assumes the 27 MHz clock is pin 4, LED0 is pin 15 (active-low), and S1 is pin 88. **S1 is a provisional pin assignment**: confirm your board revision and the actual pin against the [Sipeed documentation](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html). The CPU input is not synchronized/debounced yet.

FPGA timing, RAM mapping, and LED behavior are unverified in this package. Save your synthesis/placement reports and physical observations, even if something fails. [Record a hardware test](demo-and-results.md).

The earlier standalone LED example is separate: `make blink` and `make program-blink`.
