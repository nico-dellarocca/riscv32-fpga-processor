# Design notes

This checkpoint implements a **37-instruction RV32I subset** in
[`rv32i_core.v`](../rtl/rv32i_core.v). It has no pipeline, privileged execution,
interrupts, or variable-latency bus. The
[official RV32I specification](https://docs.riscv.org/reference/isa/v20260120/unpriv/rv32.html)
defines the instruction meanings; the implementation choices below describe
this repository. Directed tests establish specific behaviors, not ISA conformance.

## State and registered memory

`pc` holds the current instruction's byte address. `instr` holds its 32-bit
encoding. `regs[0:31]` stores integer values; combinational logic reads operands
and computes arithmetic, comparisons, addresses, and next-state decisions.
Clocked logic commits those decisions. Reset sets the PC and registers to zero.

The memory interface accepts one request per rising edge. A zero `mem_wstrb`
means read; otherwise its four bits select written byte lanes. Read data becomes
available **after** that edge. Sampling it in the same clocked block would see
the previous value.

| Rising edge | State before edge | Action |
| --- | --- | --- |
| 1 | `FETCH`, `fetch_pending=0` | Request RAM at `pc`; RAM registers the instruction word. |
| 2 | `FETCH`, `fetch_pending=1` | Copy returned data into `instr`; enter `EXEC`. No new request. |
| 3 | `EXEC` | Execute the instruction. Most instructions commit and return to `FETCH`. |
| 3, for a load | `EXEC` | Request data; save destination, width, and byte offset; enter `LOAD_WB`. |
| 4, for a load | `LOAD_WB` | Extract/extend returned data, write the destination, advance PC, and return to `FETCH`. |

No later instruction overlaps these steps, so the design is non-pipelined.
Loads retain their current PC until writeback. Stores need no returned value.
Ordinary execution advances by four bytes; taken branches and jumps select a
different PC. Jump instructions also produce the return address `pc + 4`.

The FSM therefore predicts three cycles per ordinary instruction and four per
load. Actual directed tests recorded **96 cycles** for 31 ordinary instructions
plus an illegal-zero terminator, and **89 cycles** for 24 instructions, including
14 loads, plus that terminator: `3*(24+1)+14`. These are simulation counts, not
board measurements; see [testing.md](testing.md).

## Zero register and immediates

`x0` needs protection on both paths: reads explicitly return zero, writes with
destination zero are discarded, and clocked storage keeps `regs[0]` zero.
A load into `x0` still accesses memory and can fault.

Sign extension copies an immediate's sign bit into its new upper bits. Without
it, the 12-bit representation of `-1` would become positive 4095. In the
equations below, `sext` means extension to 32 bits, and braces concatenate bits:

```text
I = sext(instr[31:20])
S = sext({instr[31:25], instr[11:7]})
B = sext({instr[31], instr[7], instr[30:25], instr[11:8], 0})
U = {instr[31:12], twelve zero bits}
J = sext({instr[31], instr[19:12], instr[20], instr[30:21], 0})
```

B and J offsets scatter their bits across the instruction. Their implicit
lowest zero expresses two-byte increments, although this core requires
four-byte instruction alignment. Branches use `pc + B`; `JAL` uses `pc + J`.
`JALR` uses `(rs1 + I) & ~1` and then checks the remaining alignment.

For example, `addi x5,x0,-1` is **`0xfff00293`**:

```text
imm[11:0]    rs1    funct3 rd     opcode
111111111111 00000  000    00101  0010011
```

The decoder selects ADDI, reads zero, extends `0xfff` to `0xffffffff`, and writes
`x5 = 0xffffffff`. The next sequential PC is four bytes later.

## Exact decoder coverage

Opcodes and `funct7` values below are hexadecimal; `funct3` values are decimal.
Lists in a row correspond position by position. A dash means that field is
part of an immediate or is irrelevant to that instruction family.

| Opcode | `funct3` | `funct7` / upper immediate | Supported mnemonics |
| --- | --- | --- | --- |
| `37` | — | — | LUI |
| `17` | — | — | AUIPC |
| `6f` | — | — | JAL |
| `67` | 0 | — | JALR |
| `63` | 0, 1, 4, 5, 6, 7 | — | BEQ, BNE, BLT, BGE, BLTU, BGEU |
| `03` | 0, 1, 2, 4, 5 | — | LB, LH, LW, LBU, LHU |
| `23` | 0, 1, 2 | — | SB, SH, SW |
| `13` | 0, 2, 3, 4, 6, 7 | — | ADDI, SLTI, SLTIU, XORI, ORI, ANDI |
| `13` | 1 | `00` | SLLI |
| `13` | 5 | `00` / `20` | SRLI / SRAI |
| `33` | 0, 1, 2, 3, 4, 5, 6, 7 | `00` | ADD, SLL, SLT, SLTU, XOR, SRL, OR, AND |
| `33` | 0, 5 | `20` | SUB, SRA |

Other encodings halt. This includes FENCE, ECALL, EBREAK, CSR operations,
compressed instructions, multiplication, and division. Register shifts use
only the lowest five count bits. SLTIU sign-extends its immediate before the
unsigned comparison.

## Byte lanes and faults

RAM is little-endian. Storing `0x80ff7f01` at `0x200` places bytes `01`, `7f`,
`ff`, `80` at successive addresses. LB at `0x203` returns `0xffffff80`; LBU
returns `0x00000080`. SB of `0xa5` at `0x201` uses strobe `0010` and shifted
write data `0x0000a500`, preserving the other three bytes. Halfwords require
even addresses; words require addresses divisible by four.

| `fault_code` | Reason |
| --- | --- |
| 1 | Unsupported or malformed instruction |
| 2 | Misaligned instruction address or taken target |
| 3 | Misaligned data access |
| 4 | Bus rejects the requested address or operation |

Faults latch `halted`, `fault_pc`, and the code until reset. They suppress
architectural updates; the SoC also rejects memory side effects. These are
debug outputs, not privileged traps. An untaken branch does not check its
unused target's alignment.

## Compiled code

`check_isa.py` checks each four-byte encoding in ELF `.text` against this
decoder. It deliberately excludes `.rodata` and `.data`, whose bytes need not
encode instructions. The script is not an emulator and cannot establish
control-flow or memory correctness. Compiled firmware must also execute in
the RTL tests, including startup, stack use, and `.bss` clearing.
