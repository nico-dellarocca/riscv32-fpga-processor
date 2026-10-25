# What has actually been tested?

The checks below were run on **October 25, 2026 while preparing the AI-assisted source package**. They were **not** independent tests performed by the student or tests of the FPGA board. The environment used Linux, Clang/LLVM 17, Python 3, and GNU Make.

## Tests that passed in the preparation environment

| Check | Result |
| --- | --- |
| Compile bare-metal C programs for RV32I | Passed |
| Assemble RV32I instruction and error-case programs | Passed |
| Python tests for the hex image converter | 4 passed |
| Python tests for reference interpreter and trace comparison | 13 passed |
| Run compiled `smoke.c` in Python RISC-V interpreter | PASS code `0x600D600D` (71 instructions) |
| Run directed `isa.S` program in Python interpreter | PASS code `0x600D600D` (138 instructions) |
| Run the short LED program in Python interpreter | Four GPIO changes (148 instructions) |
| Check local README/docs links | Passed |

To repeat these checks:

```sh
make verify
python3 scripts/check_repo.py
```

These results show that the compiled programs behave as expected **in a software model**. They do not test whether the Verilog CPU executes those programs correctly.

## Tests that still need to happen

| Test | Command / evidence to collect | Status |
| --- | --- | --- |
| Run the Verilog CPU testbench and compare instructions | `make test` (requires Icarus Verilog) | Not executed here |
| See if GitHub's automated workflow passes | Actions tab after pushing | Not checked here |
| Build the design for the Tang Nano 20K | `make soc` and saved tool reports | Not executed here |
| Load the CPU bitstream onto the board | `make program-soc` | Not attempted here |
| See a real CPU program control LED0 | Personal video, logs, notes | Not demonstrated |

`make test` will report an error if Icarus Verilog (`iverilog` and `vvp`) is not installed. No result is substituted for the missing HDL run.

There are limitations even if the HDL tests pass: the tests do not include randomized instructions, formal proofs, or the full RISC-V compliance suite. If you run new tests yourself, record the environment and actual output in [MY_WORK.md](../MY_WORK.md) and update the status here.

The earlier LED-blink programming report in [development-log.md](development-log.md) is from the supplied starter and tests a *different*, much simpler bitstream.
