.section .text.start, "ax", @progbits
.global _start
_start:
    .4byte 0x0020006f /* JAL x0, +2: unsupported IALIGN=16 target */
