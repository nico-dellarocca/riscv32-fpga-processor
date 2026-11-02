.option norvc
.option norelax
.section .text.start, "ax", @progbits
.globl _start
_start:
    la sp, __stack_top
    la gp, __global_pointer$

    # RAM already contains .text/.rodata/.data from the initialization image.
    # .bss has no bytes in that image; startup gives C its required zeroes.
    la t0, __bss_start
    la t1, __bss_end
1:
    bgeu t0, t1, 2f
    sw zero, 0(t0)
    addi t0, t0, 4
    j 1b
2:
    call main
3:
    j 3b                    # Returning from main has no operating system target.
