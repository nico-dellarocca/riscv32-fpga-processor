# The CPU

[`rv32i_core.v`](rv32i_core.v) holds the registers, program counter, instruction decoder, and the fetch/execute/load-writeback state machine. It's a small non-pipelined RV32I design. A normal instruction takes two clock cycles; a load needs an extra one because RAM reads are registered.

The CPU source was produced with substantial AI assistance. It still needs actual Verilog simulation and FPGA testing; see [test status](../../docs/verification.md) and [source notes](../../AI_ASSISTANCE.md).

If you're trying to understand it, start with `FETCH`, then trace how an `ADDI` instruction is decoded in `EXEC`. After that, follow a `LW` into `LOAD_WB`.
