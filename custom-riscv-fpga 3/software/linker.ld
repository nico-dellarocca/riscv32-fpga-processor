/* Combined 16 KiB ROM-initialized SRAM; code/data/stack share this memory. */
ENTRY(_start)
MEMORY { RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 16K }
SECTIONS {
    . = ORIGIN(RAM);
    .text : {
        KEEP(*(.text.start))
        *(.text .text.*)
    } > RAM
    .rodata : { *(.rodata .rodata.*) } > RAM
    .data : {
        . = ALIGN(4);
        *(.data .data.*)
        *(.sdata .sdata.*)
    } > RAM
    .bss (NOLOAD) : {
        . = ALIGN(4);
        __bss_start = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > RAM
    . = ALIGN(16);
    __stack_top = ORIGIN(RAM) + LENGTH(RAM);
    ASSERT(__bss_end < __stack_top - 1024, "Not enough RAM for stack")
}
