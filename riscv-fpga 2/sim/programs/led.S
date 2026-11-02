.option norvc
.option norelax
#ifndef LED_DELAY
#ifdef SIMULATION
#define LED_DELAY 3
#else
#define LED_DELAY 2250000
#endif
#endif
.section .text.start, "ax", @progbits
.globl _start
_start:
    li t0, 0x10000000
#ifdef SIMULATION
    lw t1, 4(t0)          # tb_soc supplies logical button_pressed = 1.
    li t2, 1
    bne t1, t2, fail
#endif
again:
    sw zero, 0(t0)        # Logical 0 -> physical LED_n high -> off.
    li t1, LED_DELAY
1:  addi t1, t1, -1
    bne t1, zero, 1b
    li t2, 1
    sw t2, 0(t0)          # Logical 1 -> physical LED_n low -> on.
    li t1, LED_DELAY
2:  addi t1, t1, -1
    bne t1, zero, 2b
    sw zero, 0(t0)
#ifdef SIMULATION
    li t1, 1
    sw t1, 16(t0)        # This register exists only in the simulation SoC.
3:  j 3b
fail:
    li t1, 5
    sw t1, 16(t0)
4:  j 4b
#else
    j again
#endif
