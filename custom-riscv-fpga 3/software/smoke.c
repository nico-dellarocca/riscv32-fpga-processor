/* Compiled-C acceptance test. CPU must execute this program to write PASS. */
#include <stdint.h>
#define GPIO_OUT  (*(volatile uint32_t *)0x10000000u)
#define TEST_EXIT (*(volatile uint32_t *)0x10000010u)
#define PASS 0x600d600du
#define FAIL 0xdeadbeefu

volatile uint32_t total;
volatile uint32_t seed = 7; /* .data initialization must survive boot */

int main(void) {
    volatile uint32_t a = 10;
    volatile uint32_t b = 20;
    uint32_t sum = a + b;
    for (uint32_t i = 0; i < seed; ++i) sum += i;
    total = sum;
    if (total == 51 && a == 10 && b == 20) {
        GPIO_OUT = 1;
        TEST_EXIT = PASS;
    } else {
        GPIO_OUT = 0;
        TEST_EXIT = FAIL;
    }
    for (;;) { }
}
