# Testing and evidence

This records commands actually executed on **2026-10-29**, with their scope.
No FPGA board was connected. Logs under `evidence/` are actual tool output;
absolute workspace paths in those logs identify this run, not paths users must
recreate. No benchmark, waveform or hardware observation has been invented.

## Reproduce the checks

Run from the repository root with Icarus Verilog, Python 3 and GNU Make:

```sh
make sim
make firmware
make images
make sim
make synth YOSYS=yowasp-yosys
```

`make sim` runs the checked-in images. `make firmware` compiles all seven
assembly/C variants and checks every `.text` encoding. `make images` replaces
the checked-in fixtures with those new outputs, including the C `.bss` bounds.
Always rerun simulation after regenerating images. `make sim-firmware` combines
the latter operations. All failure paths return nonzero; shell pipelines in
the simulation target use `pipefail` so `tee` cannot hide a failed bench.

Tools used here: **Icarus Verilog 12.0**, **GCC 13.2.0** for
`riscv64-unknown-elf`, **GNU binutils 2.42**, Python 3.12, and **Yosys 0.70**
(git `28ba3cb92`, YoWASP package `0.70.0.0.post1259`). GCC was explicitly
configured for RV32I/ILP32. Tool executables were installed outside the delivered
source tree. No compiler, simulator, or synthesized bitstream is bundled.

The actual session selected executable paths with `IVERILOG`, `VVP`,
`RISCV_PREFIX` and `YOSYS`. A writable `TMPDIR` was required by this execution
environment. The final compiler rebuild used ordinary project flags, without
the temporary tool-repair workaround described below.

## Evidence table

| Check | Status | Actual evidence and limit |
| --- | --- | --- |
| Source files and RAM fixtures | PASS | Files are present; source and generated images have separate roles. |
| Blink counter | PASS | `tb_blink` checked every cycle through 32 clocks, with four expected transitions. |
| CPU arithmetic | PASS | All 21 ALU/upper-immediate mnemonics, immutable `x0`, negative immediates and masked shift count; 96 counted clocks. |
| CPU memory | PASS | All 8 load/store mnemonics, signed/unsigned extension, lane preservation and negative offsets; 89 clocks, including 14 `LOAD_WB` cycles. |
| CPU control flow | PASS | All 6 branches taken and untaken; backward and scattered-bit offsets; JAL/JALR links and target-bit handling. |
| CPU faults | PASS | Illegal/reserved encodings, unsupported instructions, misalignment, rejected reads/writes/fetches, no subsequent side effects and sticky halt. |
| Assembly through the real SoC | PASS | Arithmetic, RAM, branch and GPIO images reached code 1; GPIO actual output checked after each of three writes. |
| C smoke program | PASS | Exact compiled image executed; `.bss` deliberately poisoned first; initialized data, real stack accesses, RAM and GPIO checks completed. |
| SoC address permissions | PASS | Button stores, above-RAM stores and byte writes to word-only completion rejected without aliasing RAM. |
| Board wrapper digital behavior | PASS | Seven-edge accelerated reset, two-stage button rise/fall, LED inversion and hardware-mode completion rejection. |
| Firmware compilation/encoding validation | PASS | Seven ELF images built; every `.text` word accepted by the explicit checker. See `firmware.log`. |
| Fixture regeneration | PASS | All six `.mem` files and `.bss` bounds reproduced byte for byte; current hashes in `images.sha256`. |
| GW2A-targeted synthesis | PASS | Yosys completed; eight `SP` RAM cells; final structural check reported zero problems. Mapping warnings retained below. |
| Place-and-route and 27 MHz timing | NOT RUN | No placed design, timing report, or pin-constraint implementation result. |
| FPGA programming | NOT RUN | No board or programmer operation. |
| Physical LED/button behavior | NOT RUN | No physical observation or electrical measurement. |
| Independent ISA conformance/formal verification | NOT RUN | Directed tests and encoding checks do not establish full architectural compliance. |

All four HDL benches returned exit code 0. See
[simulation.log](evidence/simulation.log) for complete output.

## What the counts mean

| SoC program | Clocks from reset release through completion | Accepted LED writes |
| --- | ---: | ---: |
| `arithmetic.mem` | 60 | 0 |
| `memory.mem` | 108 | 0 |
| `branch.mem` | 90 | 0 |
| `led.mem` | 73 | 3 |
| `c_smoke.mem` | 433 | 3 |

These are counters in `tb_soc`, including instruction fetch and the completion
store. They are simulation results, not elapsed board time or performance
benchmarks. The testbench's 10 ns clock is a convenient simulation stimulus;
it does not establish a 100 MHz hardware clock capability.

The isolated CPU arithmetic count includes 31 instructions and an intentional
illegal-zero terminator: `32*3 = 96`. The memory count includes 24 instructions,
14 of them loads, plus its terminator: `25*3 + 14 = 89`. This tests the intended
three-cycle ordinary instruction and four-cycle load behavior.

The GPIO monitor checks each requested value **and** the registered LED output
after the update. The C test overwrites five `.bss` words at
`[0x250, 0x264)` with `0xdeadbeef`; startup must clear them. The observed C image
uses 580 text bytes, 12 initialized-data bytes and 20 `.bss` bytes. Both C
variants contain 145 checked instruction words. See
[firmware_sim.lst](evidence/firmware_sim.lst) for the actual disassembly.

The compiler selected unsigned loads followed by shifts for some signed C
accesses. Direct `LB`/`LH` semantics are tested in the memory assembly and
directed core bench. The hardware C variant has compiled and passed encoding
checks; its sustained LED/button loop has not been observed on a board.

## Synthesis result and limits

The actual synthesis command is the one in `make synth`:

```text
read_verilog rtl/rv32i_core.v rtl/rv32_soc.v rtl/tangnano20k_top.v
synth_gowin -family gw2a -top tangnano20k_top -json build/soc.json
check
stat
```

[synthesis.log](evidence/synthesis.log) retains the complete successful output.
The RAM became eight `SP` primitives, each with `BIT_WIDTH=4`, providing
`4096 * 4 * 8 = 131072` data bits. The final `check` reported zero problems.
The raw JSON was inspected for those cell parameters; it is a regenerable
build output, not a delivered implementation or programmed image.

Four warnings came from Yosys's `gowin/brams_map.v` when a generic data-packing
macro expanded beyond a four-bit slice. Inspection of all eight mapped cells
found their active `DI[3:0]` inputs driven; the remaining 28 inputs were unused
`x` padding for the selected four-bit mode. This explains the warnings at the
netlist level; it is not a gate-level or electrical validation. The log also
contains an ABC9 template lexer warning about `bit` outside SystemVerilog mode.
These warnings are preserved, not hidden or described as a warning-free run.

Synthesis does not establish device fit, routing, clock frequency, startup
configuration behavior, or working pin constraints. Use the current
[Yosys command reference](https://yosyshq.readthedocs.io/projects/yosys/en/v0.70/cmd/index_techlibs_gowin.html)
and [YoWASP installation instructions](https://yowasp.org/) for the optional
open toolchain, then carry out the separate implementation and board gates.

## Actual issues encountered and corrections

| Attempt | Observed result | Correction and subsequent evidence |
| --- | --- | --- |
| Initial dependency checks | `iverilog` and the RISC-V compiler were unavailable. | Installed local tools; actual RTL and compiler runs then completed. |
| First Icarus invocation with default temporary directory | `Error opening temporary file /tmp/ivrlg67096fcd` | Selected the writable session `TMPDIR`; no behavioral failure was involved. |
| Incomplete compiler package | `fatal error: '-fuse-linker-plugin', but liblto_plugin.so not found` | Repaired and checksum-verified the full package. The final forced rebuild used default flags. |
| First strict C link | `error: unplaced orphan section .rela.text.start` | Collected relocation metadata explicitly and asserted that the runtime relocation section is empty; C linking and RTL execution then passed. |
| Initial native Yosys in restricted runtime | `readlink("/proc/self/exe") failed` | Ran the tool where ordinary executable metadata was available. |
| Yosys 0.33 synthesis | `Unknown option` at `-family gw2a` | Used current Yosys 0.70, retaining the exact family request; synthesis then completed. Initial log is `synth-initial.log`. |
| Review of the original GPIO monitor | It checked bus writes and final LED state, leaving the intermediate on-state insufficiently checked. | Added a check of the actual LED register after every accepted write; the final complete RTL suite passed. |
| Icarus timescale warnings | Modules lacked explicit timescales. | Added consistent timescales; the final compiled benches produced no such warnings. |

The linker also reports an RWX ELF load segment for unified code/data RAM.
This reflects the documented absence of memory protection and remains visible
in the log. No failed HDL behavioral assertion occurred in this session.
Future test changes should preserve the expected-value checks rather than
merely wait for the simulation to finish.
