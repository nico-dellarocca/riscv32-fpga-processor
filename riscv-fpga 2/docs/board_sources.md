# Board wiring and bring-up assumptions

Checked against Sipeed's **Tang Nano 20K PCB 3921**, schematic **Rev 1.30,
2023-07-11**, on 2026-10-29. This is a document check; no physical board was
available for measurement. Confirm the revision printed on your own board.

| RTL port | FPGA package pin | Evidence and chosen setting |
| --- | --- | --- |
| `clk` | 4 | MAIN: U3 `OSC_27MHz`, via R10, drives `PIN04_SYS_CLK`. Nominal 27 MHz; LVCMOS33. |
| `led0_n` | 15 | MAIN maps `PIN15_SYS_LED0`; PERIPHERALS connects LED0 to +3V3 through its LED/resistor path. Low turns it on; LVCMOS33. |
| `button_s1` | 88 | MAIN maps `PIN88_MODE0_KEY1` and R6, a 1 kΩ pulldown. PERIPHERALS connects S1 to +3V3 through R43, 330 Ω. Released = low; pressed = high. LVCMOS33, `PULL_MODE=NONE`. |

Sources:

- [Sipeed schematic, Rev 1.30](https://dl.sipeed.com/fileList/TANG/Nano_20K/2_Schematic/Tang_Nano_20K_3921_Schematics.pdf), sheets `MAIN` and `PERIPHERALS`.
- [Sipeed board introduction](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html), clock and LED descriptions.
- [Sipeed LED tutorial](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/example/led.html), Gowin project and programming workflow.

The S1 signal shares the FPGA MODE0 configuration pin. Test button input after
configuration; leave it released during programming and startup until the mode
settings for your programming method have been checked. The schematic establishes
the shared pin, not the outcome of every possible boot configuration.

## Counter experiment

`examples/blink.v` has a configurable free-running counter. Its most significant
bit controls logical LED state. With `COUNTER_BITS=25`, that bit changes every
`2^24` clocks: approximately 0.621 seconds at the nominal 27 MHz. The full period
is approximately 1.243 seconds. These are calculated values, not measurements.
The testbench selects four bits and checks transitions at clocks 8, 16, 24 and 32,
including the active-low output. Use a positive counter width.

## Reset and asynchronous input

The SoC wrapper initializes an eight-bit counter to zero. It holds synchronous
reset high for the first 255 clock edges, then saturates. Both designs rely on
the FPGA configuration flow preserving Verilog initial register values.
GW2A-targeted synthesis completed in this session, but configuration behavior
still needs implementation and board verification. The wrapper has no
manual reset and does not detect brownouts. Reconfiguration restarts the design.

The button passes through two flip-flops before reaching the memory-mapped input.
Only the second stage is consumed. This reduces metastability propagation;
switch bounce can still produce several transitions. A level-reading experiment
can inspect that raw synchronized value. A one-action-per-press extension needs
a verified hardware or software debounce interval.

Declare a 27 MHz clock in the FPGA timing constraints (period approximately
37.037 ns). Synthesis inferred eight block-memory cells; see `testing.md` for
the actual report and mapping warnings. Placement, clock routing, configuration
initialization and timing closure remain separate acceptance checks.
