.option norvc
.option norelax
.section .text.start, "ax", @progbits
.globl _start
_start:
    addi x1, zero, 5
    addi x2, zero, 7
    add x3, x1, x2
    addi t0, zero, 12
    bne x3, t0, fail
    addi x4, zero, -17
    addi t0, zero, -17
    bne x4, t0, fail
    slli x5, x1, 3
    addi t1, zero, 40
    bne x5, t1, fail
    sub x6, x3, x2
    bne x6, x1, fail
    addi zero, zero, 123   # A write to x0 must be discarded.
    add t0, zero, zero
    bne t0, zero, fail
    li t0, 0x10000010
    li t1, 1
    sw t1, 0(t0)
1:  j 1b
fail:
    li t0, 0x10000010
    li t1, 2
    sw t1, 0(t0)
2:  j 2b
