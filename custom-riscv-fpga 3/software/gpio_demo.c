/* FPGA LED demonstration: an RV32I *program* changes the GPIO register. */
#include <stdint.h>
#define GPIO_OUT (*(volatile uint32_t *)0x10000000u)
#ifdef SIM_FAST
#define DELAY_CYCLES 8u
#else
#define DELAY_CYCLES 150000u
#endif

static void delay(void) {
    for (volatile uint32_t i = 0; i < DELAY_CYCLES; ++i) { }
}

int main(void) {
    while (1) {
        GPIO_OUT = 1u;
        delay();
        GPIO_OUT = 0u;
        delay();
    }
}
