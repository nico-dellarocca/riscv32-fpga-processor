/* This demonstrates CPU-executed C once the RV32I core exists.
 * It has NOT yet run on the custom CPU.
 */
#include <stdint.h>

volatile uint32_t result;

int main(void) {
    volatile uint32_t a = 10u;
    volatile uint32_t b = 20u;
    result = a + b;
    while (1) { }
    return 0;
}
