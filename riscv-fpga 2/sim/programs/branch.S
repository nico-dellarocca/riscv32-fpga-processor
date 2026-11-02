.option norvc
.option norelax
.section .text.start, "ax", @progbits
.globl _start
_start:
    li s0, 0
    li t0, 3
loop:
    addi s0, s0, 1
    addi t0, t0, -1
    bne t0, zero, loop    # Negative B immediate, taken twice then not taken.
    li t1, 3
    bne s0, t1, fail
    li t0, -2
    li t1, 1
    blt t0, t1, signed_ok
    j fail
signed_ok:
    bge t0, t1, fail
    bltu t0, t1, fail     # 0xfffffffe is large when compared as unsigned.
    bgeu t0, t1, unsigned_ok
    j fail
unsigned_ok:
    beq t0, t1, fail
    bne t0, t1, unequal_ok
    j fail
unequal_ok:
    jal ra, add_four
    li t1, 7
    bne s0, t1, fail
    li t0, 0x10000010
    li t1, 1
    sw t1, 0(t0)
1:  j 1b
add_four:
    addi s0, s0, 4
    jalr zero, 0(ra)
fail:
    li t0, 0x10000010
    li t1, 4
    sw t1, 0(t0)
2:  j 2b
