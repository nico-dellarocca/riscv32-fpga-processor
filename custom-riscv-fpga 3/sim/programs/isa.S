/* Directed RV32I architectural acceptance test. Builds with LLVM's assembler.
 * Includes signed/unsigned ALU, immediates, shifts, loads/stores, branches,
 * JAL/JALR, FENCE, x0, address alignment, and a final MMIO signature.
 */
.section .text.start, "ax", @progbits
.option norvc
.global _start
.macro CHECK reg, expected
    li t6, \expected
    bne \reg, t6, fail
.endm
_start:
    li t0, 7
    li t1, 3
    add t2, t0, t1
    CHECK t2, 10
    sub t2, t0, t1
    CHECK t2, 4
    and t2, t0, t1
    CHECK t2, 3
    or t2, t0, t1
    CHECK t2, 7
    xor t2, t0, t1
    CHECK t2, 4
    sll t2, t1, t1
    CHECK t2, 24
    srl t2, t2, t1
    CHECK t2, 3
    li t0, -16
    sra t2, t0, t1
    CHECK t2, -2
    slt t2, t0, t1
    CHECK t2, 1
    sltu t2, t0, t1
    CHECK t2, 0
    addi t2, t1, -8
    CHECK t2, -5
    xori t2, t1, -1
    CHECK t2, -4
    ori t2, t1, 8
    CHECK t2, 11
    andi t2, t1, 2
    CHECK t2, 2
    slti t2, t0, 0
    CHECK t2, 1
    sltiu t2, t1, -1
    CHECK t2, 1
    slli t2, t1, 5
    CHECK t2, 96
    srli t2, t2, 3
    CHECK t2, 12
    srai t2, t0, 2
    CHECK t2, -4
    lui t2, 0x12345
    CHECK t2, 0x12345000
auipc_mark:
    auipc t3, 0
    /* The PC used by AUIPC is exactly its instruction address. */
    la t4, auipc_mark
    bne t3, t4, fail
    blt t0, t1, signed_less
    j fail
signed_less:
    bge t1, t0, signed_ge
    j fail
signed_ge:
    bltu t1, t0, unsigned_less
    j fail
unsigned_less:
    bgeu t0, t1, unsigned_ge
    j fail
unsigned_ge:
    beq t1, t1, eq_taken
    j fail
eq_taken:
    beq t1, t0, fail
    bne t1, t0, ne_taken
    j fail
ne_taken:
    bne t1, t1, fail

    /* Check byte lanes and sign/zero extension. */
    la t4, scratch
    li t5, 0x80ff0180
    sw t5, 0(t4)
    lw t2, 0(t4)
    CHECK t2, 0x80ff0180
    lb t2, 0(t4)
    CHECK t2, -128
    lbu t2, 0(t4)
    CHECK t2, 128
    lh t2, 2(t4)
    CHECK t2, -32513
    lhu t2, 2(t4)
    CHECK t2, 33023
    li t5, 0x33
    sb t5, 1(t4)
    lbu t2, 1(t4)
    CHECK t2, 0x33
    li t5, 0x5566
    sh t5, 2(t4)
    lh t2, 2(t4)
    CHECK t2, 0x5566
    lw t2, 0(t4)
    CHECK t2, 0x55663380

    /* Check link and return for JAL and the cleared LSB for JALR. */
    jal ra, subroutine
return_from_jal:
    CHECK a0, 0x123
    la t4, subroutine_jalr
    addi t4, t4, 1
    jalr ra, t4, 0
return_from_jalr:
    CHECK a0, 0x456
    fence
    addi zero, zero, 11
    bne zero, zero, fail

pass:
    li t4, 0x10000000
    li t5, 1
    sw t5, 0(t4)
    li t4, 0x10000010
    li t5, 0x600d600d
    sw t5, 0(t4)
    j pass
fail:
    li t4, 0x10000010
    li t5, 0xdeadbeef
    sw t5, 0(t4)
    j fail
subroutine:
    li a0, 0x123
    ret
subroutine_jalr:
    li a0, 0x456
    ret
.section .bss, "aw", @nobits
.balign 4
scratch:
    .space 16
