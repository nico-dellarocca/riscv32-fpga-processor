# Memory and GPIO contract

All addresses are byte addresses. The single CPU interface carries `mem_req`,
`mem_addr`, `mem_wdata`, four `mem_wstrb` bits, registered `mem_rdata`, and a
combinational `mem_fault`. A zero strobe mask denotes a read; each asserted
strobe writes one byte. There is no ready signal: every accepted read is
registered on its request edge. The CPU samples it on a later edge.

| Byte addresses | Access | Meaning |
| --- | --- | --- |
| `0x00000000`–`0x00003fff` | Read/write | 4096 32-bit words: 16 KiB program, data, and stack RAM |
| `0x10000000`–`0x10000003` | Read/write | LED register, bit 0 = logical on; other bits read zero |
| `0x10000004`–`0x10000007` | Read only | Button register, bit 0 = synchronized logical pressed |
| `0x10000010` | Simulation-only full-word write | Completion event and code; `1` means PASS to the testbench |
| Everything else | Rejected | CPU halts with bus fault code 4 |

The completion address exists only when `SIMULATION=1`. Every accepted full-word
write sets sticky `sim_done` and captures `sim_code`. The bench rejects any code
other than 1, including zero; firmware uses other codes for failures. Reads and
partial stores are rejected. `tangnano20k_top` fixes `SIMULATION=0`, so this
address is absent in hardware. `sim_done` itself does not stop the CPU; the
bench ends the test and the firmware waits in a loop.

## Width, alignment and byte order

`LW`/`SW` require addresses divisible by four. Halfword accesses require even
addresses. Byte accesses may use any byte address. The CPU rejects a misaligned
access before issuing a bus request. Accepted loads return the aligned word;
the CPU selects the addressed bytes and performs the requested sign or zero
extension in `LOAD_WB`.

RAM is little endian. Storing `0x80fe7f01` at address `A` puts `01`, `7f`, `fe`,
`80` at `A` through `A+3`. `LB A+3` returns `0xffffff80`; `LBU A+3` returns
`0x00000080`. `SB` to `A+1` selects strobe `0010`, shifts the source byte into
data bits 15:8, and leaves the other bytes unchanged. A halfword store at
`A+2` selects `1100`. The core and SoC use the same lane convention.

GPIO reads return a word whose only nonzero bit can be bit 0. Consequently,
byte/halfword reads of reserved upper bytes return zero. Stores to LED update
bit 0 only when strobe 0 is enabled. Upper-lane writes are accepted and ignored;
other bits of the low byte are also ignored. Any store to the button register
faults. Every rejected request is suppressed at the memory/peripheral boundary,
so even a rejected store cannot change a register or alias RAM.

There is no execute-permission bit. Instruction fetches use the same read
interface as data; attempting to execute a peripheral's value will generally
reach an illegal instruction. Software should execute only linked RAM code.

## Logical versus physical levels

Writing LED bit 0 = 1 means **on**. The board wrapper drives `led0_n = ~led`
after startup reset; its physical pin is therefore low when on. Reset forces
the output high/off.

On the documented PCB 3921 schematic, S1 has an external pulldown and closes
toward +3V3, so pressed = high. Two sampling flip-flops preserve that polarity
before the value enters the SoC. The SoC's standalone testbench supplies an
already-logical button value. Wiring sources and the exact revision are in
[board_sources.md](board_sources.md). Document verification is distinct from
observing an actual switch on a programmed board.

## RAM images and reset

`tools/bin_to_mem.py` reads a raw little-endian binary and writes exactly 4096
lines of eight hexadecimal digits each. Line 0 initializes RAM word 0. For
example, input bytes `44 33 22 11` become the line `11223344`. A final partial
word is zero-padded, and every unused word is explicitly zero. Images larger
than 16 KiB are rejected. No addresses are silently relocated or corrected.

RAM uses configuration-time initialization and a synchronous read register.
Reset clears CPU state and peripheral registers; it does not clear the whole
RAM. Unused zero words decode as illegal instructions if reached. They are not
NOPs. Actual configuration retention still requires board verification.

The linker places `.text`, `.rodata`, `.data` and `.bss` in RAM. `.bss` has no
binary payload and startup clears it explicitly. The SoC test overwrites the
compiled `.bss` range with `0xdeadbeef` before execution to exercise that loop.
`c_smoke.bss` records the two boundary symbols from the actual ELF and is
regenerated alongside its image.

The initial stack pointer is `0x4000`, one byte beyond RAM; the stack grows
down. The linker reserves the top 1 KiB (`0x3c00`–`0x3fff`) and rejects a static
image that overlaps it. This reserve is a build-time layout rule, not a runtime
stack bound check or a proof of worst-case stack use.
