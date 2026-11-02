/* Freestanding C: no library, division, multiplication, CSR or privileged code. */
typedef unsigned int u32;
_Static_assert(sizeof(u32) == 4, "This firmware requires 32-bit unsigned int");
_Static_assert(sizeof(short) == 2, "This firmware requires 16-bit short");

#define LED (*(volatile u32 *)0x10000000u)
#define BUTTON (*(volatile u32 *)0x10000004u)
#ifdef SIMULATION
#define COMPLETE (*(volatile u32 *)0x10000010u)
#endif
#ifndef LED_DELAY
#define LED_DELAY 2250000u
#endif

static volatile u32 zero_words[4];
static volatile u32 initialized_word = 0x12345678u;
static volatile u32 operand_a = 5u, operand_b = 7u;
static volatile union {
    u32 word;
    unsigned char byte[4];
    signed char signed_byte[4];
    unsigned short half[2];
    short signed_half[2];
} probe;

/* A volatile local array makes this smoke test exercise the initialized stack. */
static __attribute__((noinline)) u32 add_from_stack(u32 a, u32 b)
{
    volatile u32 pair[2] = { a, b };
    return pair[0] + pair[1];
}

static void fail(u32 code)
{
#ifdef SIMULATION
    COMPLETE = 0xbad00000u | code;
#else
    (void)code;
    LED = 1u;
#endif
    for (;;) { }
}

#ifndef SIMULATION
static void delay(u32 count)
{
    while (count != 0u) {
        __asm__ volatile ("" ::: "memory");
        --count;
    }
}
#endif

int main(void)
{
    for (u32 i = 0; i < 4u; ++i)
        if (zero_words[i] != 0u) fail(1u);
    if (probe.word != 0u) fail(2u);
    if (initialized_word != 0x12345678u) fail(3u);
    if (add_from_stack(operand_a, operand_b) != 12u) fail(4u);

    /* Volatile accesses force real RAM loads/stores and signed extensions. */
    probe.word = 0x80fe7f01u;
    if (probe.byte[0] != 1u || probe.byte[1] != 127u ||
        probe.byte[2] != 254u || probe.byte[3] != 128u) fail(5u);
    if (probe.signed_byte[3] != -128) fail(6u);
    if (probe.half[0] != 0x7f01u || probe.half[1] != 0x80feu ||
        probe.signed_half[1] != -32514) fail(7u);
    probe.byte[1] = 0xa5u;
    probe.half[1] = 0x1234u;
    if (probe.word != 0x1234a501u) fail(8u);

#ifdef SIMULATION
    LED = 0u;
    LED = 1u;
    LED = 0u;
    COMPLETE = 1u;
    for (;;) { }
#else
    /* The synchronized logical button keeps LED0 on while it is pressed.
       Level sensing needs no debounce; counting presses would need debounce. */
    u32 phase = 0u;
    for (;;) {
        LED = (BUTTON & 1u) ? 1u : phase;
        delay(LED_DELAY);
        phase ^= 1u;
    }
#endif
}
