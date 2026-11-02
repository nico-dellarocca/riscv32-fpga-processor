.option norvc
.option norelax
.section .text.start, "ax", @progbits
.globl _start
_start:
    la t0, scratch
    li t1, 0x80fe7f01
    sw t1, 0(t0)
    lw t2, 0(t0)
    bne t1, t2, fail
    lb t2, 3(t0)
    li t3, -128
    bne t2, t3, fail
    lbu t2, 2(t0)
    li t3, 254
    bne t2, t3, fail
    lh t2, 2(t0)
    li t3, -32514
    bne t2, t3, fail
    lhu t2, 2(t0)
    li t3, 0x80fe
    bne t2, t3, fail
    li t1, 0xa5
    sb t1, 1(t0)
    li t1, 0x1234
    sh t1, 2(t0)
    lw t2, 0(t0)
    li t3, 0x1234a501
    bne t2, t3, fail
    li t0, 0x10000010
    li t1, 1
    sw t1, 0(t0)
1:  j 1b
fail:
    li t0, 0x10000010
    li t1, 3
    sw t1, 0(t0)
2:  j 2b
.section .bss, "aw", @nobits
.balign 4
scratch:
    .space 4
