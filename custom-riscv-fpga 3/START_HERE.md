# Start here

This repository is a work-in-progress RISC-V CPU project. You can read the code and run parts of it without owning the FPGA board, but the hardware result is still untested.

## A manageable order to work through it

1. **Read [`examples/01_blink/blink.v`](examples/01_blink/blink.v).** Make sure you understand the clock counter and why the LED output is inverted.
2. **Read [`software/gpio_demo.c`](software/gpio_demo.c).** Find the address the program writes to turn the LED on and off.
3. **Run `make verify`.** This checks the compiled machine code in a Python model. Write the actual result and your tool versions in [MY_WORK.md](MY_WORK.md).
4. **Install Icarus Verilog and run `make test`.** This is the first check of the newer CPU RTL. If it fails, save the output and work through the first error.
5. **Try `make soc` only after simulation works.** It needs Gowin FPGA tools. Confirm your board's pin assignments and review timing before programming the FPGA.
6. **Only after a real successful board run**, record what the LED did and attach your own demo video or photos.

If you are publishing this to GitHub, see [docs/publishing.md](docs/publishing.md). Read [AI_ASSISTANCE.md](AI_ASSISTANCE.md) before describing the work as your own.
