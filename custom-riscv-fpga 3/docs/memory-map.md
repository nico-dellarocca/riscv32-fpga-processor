# Address map as implemented in the SoC RTL

| Address | Size | Access | Function |
|---|---:|---|---|
| `0x00000000`–`0x00003FFF` | 16 KiB | R/W | Unified RAM: code, initialized data, `.bss`, and stack |
| `0x10000000` | 32 bits | R/W | GPIO output, bit 0 logical LED ON (pin inverted) |
| `0x10000004` | 32 bits | R | GPIO input, bit 0 logical S1 pressed (unverified pin mapping) |
| `0x10000010` | 32 bits | W | Simulation-only completion code; `0x600D600D` means PASS |
| All other addresses | — | R=0 / W ignored | No bus fault raised |

All accesses are byte addressed and little-endian. Aligned `LW/SW` and `LH/SH` only. Unaligned loads/stores stop the CPU; there is no misalignment emulation. A 32-bit RAM word address selects the containing four-byte word. A byte store enables a single lane; a halfword store enables exactly two lanes. The output latch accepts byte strobes.

**No UART peripheral exists in this build.** Original starter notes contained proposed UART addresses; they have deliberately not been carried into the implemented map. The signature register is diagnostic and should not be confused with a general-purpose serial port. This register has no effect on the board's LED.
