CC = clang
OBJCOPY = llvm-objcopy
OUT = ../build/programs
CFLAGS = -target riscv32-unknown-elf -march=rv32i -mabi=ilp32 -nostdlib \
  -Wl,--no-relax -Wl,--gc-sections -T ../../software/linker.ld
SOURCES := isa illegal misaligned_load misaligned_pc ecall ebreak
HEXS := $(addprefix $(OUT)/,$(addsuffix .hex,$(SOURCES)))

.PHONY: all clean
all: $(HEXS)
$(OUT):
	mkdir -p $(OUT)
$(OUT)/%.elf: %.S ../../software/linker.ld | $(OUT)
	$(CC) $(CFLAGS) -o $@ $<
$(OUT)/%.bin: $(OUT)/%.elf
	$(OBJCOPY) -O binary $< $@
$(OUT)/%.hex: $(OUT)/%.bin
	python3 ../../scripts/bin_to_mem.py --input $< --output $@ --size-bytes 16384
clean:
	rm -rf ../build/programs
