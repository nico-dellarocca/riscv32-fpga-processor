# LLVM RISC-V toolchain (clang/llvm-objcopy/llvm-objdump) works on Linux or macOS.
# For GNU cross-toolchains, override CC/OBJCOPY/OBJDUMP at make invocation.
CC = clang
OBJCOPY = llvm-objcopy
OBJDUMP = llvm-objdump
OUT = build
ARCH = -target riscv32-unknown-elf -march=rv32i -mabi=ilp32
CFLAGS = $(ARCH) -O1 -g -ffreestanding -fno-builtin -fno-pic \
  -fno-stack-protector -fno-common -Wall -Wextra -ffunction-sections \
  -fdata-sections -msmall-data-limit=0
LDFLAGS = -nostdlib -Wl,--gc-sections -Wl,--no-relax \
  -T linker.ld
BIN2MEM = python3 ../scripts/bin_to_mem.py --size-bytes 16384

.PHONY: all clean disasm
all: $(OUT)/hello.hex $(OUT)/smoke.hex $(OUT)/gpio_demo.hex $(OUT)/gpio_fast.hex

$(OUT):
	mkdir -p $(OUT)

$(OUT)/hello.elf: hello.c start.S linker.ld | $(OUT)
	$(CC) $(CFLAGS) $(LDFLAGS) -Wl,-Map,$(OUT)/hello.map -o $@ start.S hello.c

$(OUT)/smoke.elf: smoke.c start.S linker.ld | $(OUT)
	$(CC) $(CFLAGS) $(LDFLAGS) -Wl,-Map,$(OUT)/smoke.map -o $@ start.S smoke.c

$(OUT)/gpio_demo.elf: gpio_demo.c start.S linker.ld | $(OUT)
	$(CC) $(CFLAGS) $(LDFLAGS) -Wl,-Map,$(OUT)/gpio_demo.map -o $@ start.S gpio_demo.c

$(OUT)/gpio_fast.elf: gpio_demo.c start.S linker.ld | $(OUT)
	$(CC) $(CFLAGS) -DSIM_FAST=1 $(LDFLAGS) -Wl,-Map,$(OUT)/gpio_fast.map -o $@ start.S gpio_demo.c

$(OUT)/%.bin: $(OUT)/%.elf
	$(OBJCOPY) -O binary $< $@

$(OUT)/%.hex: $(OUT)/%.bin
	$(BIN2MEM) --input $< --output $@

disasm: $(OUT)/smoke.elf
	$(OBJDUMP) --no-show-raw-insn -d $<

clean:
	rm -rf $(OUT)
