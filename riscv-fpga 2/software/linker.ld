OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY { RAM (rwx) : ORIGIN = 0, LENGTH = 16K }

SECTIONS
{
    .text : ALIGN(4) {
        KEEP(*(.text.start))
        *(.text .text.* .init .init.* .fini .fini.*)
    } > RAM
    .rodata : ALIGN(4) { *(.rodata .rodata.* .srodata .srodata.*) } > RAM
    .data : ALIGN(4) {
        __global_pointer$ = . + 0x800;
        *(.data .data.* .sdata .sdata.*)
    } > RAM
    .rela.dyn : { *(.rela.*) } > RAM
    ASSERT(SIZEOF(.rela.dyn) == 0, "Runtime relocations are not supported")
    .bss (NOLOAD) : ALIGN(4) {
        __bss_start = .;
        *(.bss .bss.* .sbss .sbss.*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > RAM
    __image_end = .;
    __stack_top = ORIGIN(RAM) + LENGTH(RAM);
    __stack_limit = __stack_top - 1024;
    ASSERT(__image_end <= __stack_limit, "Image overlaps reserved 1 KiB stack")

    .riscv.attributes 0 : { *(.riscv.attributes) }
    /DISCARD/ : { *(.comment .note* .eh_frame*) }
}
