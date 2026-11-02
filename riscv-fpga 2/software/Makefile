RISCV_PREFIX ?= riscv64-unknown-elf-
PYTHON ?= python3
BUILD ?= ../build/firmware
LED_DELAY ?= 2250000
CC := $(RISCV_PREFIX)gcc
OBJCOPY := $(RISCV_PREFIX)objcopy
OBJDUMP := $(RISCV_PREFIX)objdump
SIZE := $(RISCV_PREFIX)size
NM := $(RISCV_PREFIX)nm
ISA_FLAGS = -march=rv32i -mabi=ilp32 -mno-relax -msmall-data-limit=0
CFLAGS = $(ISA_FLAGS) -Os -std=gnu11 -Wall -Wextra -Werror -ffreestanding \
         -fno-builtin -fno-pic -fno-pie -fno-stack-protector \
         -fno-unwind-tables -fno-asynchronous-unwind-tables \
         -ffunction-sections -fdata-sections
LDFLAGS = -nostdlib -nostartfiles -Wl,-T,linker.ld,--gc-sections,--no-relax \
          -Wl,--orphan-handling=error,--build-id=none
PROGRAMS = arithmetic memory branch led
PROGRAM_MEM = $(addprefix $(BUILD)/,$(addsuffix .mem,$(PROGRAMS)))

.PHONY: all programs images check-tools clean
.SECONDARY:
all: check-tools $(BUILD)/firmware_sim.mem $(BUILD)/firmware_hw.mem programs
programs: check-tools $(PROGRAM_MEM) $(BUILD)/led_hw.mem

check-tools:
	@for tool in "$(CC)" "$(OBJCOPY)" "$(OBJDUMP)" "$(SIZE)" "$(NM)" "$(PYTHON)"; do \
	  command -v "$$tool" >/dev/null 2>&1 || { \
	    echo "NOT RUN: $$tool unavailable; install a RISC-V bare-metal GCC toolchain or set RISCV_PREFIX"; exit 1; }; \
	done

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/firmware_sim.elf: start.S main.c linker.ld | $(BUILD) check-tools
	$(CC) $(CFLAGS) -DSIMULATION $(LDFLAGS) -Wl,-Map,$(@:.elf=.map) start.S main.c -o $@

$(BUILD)/firmware_hw.elf: start.S main.c linker.ld | $(BUILD) check-tools
	$(CC) $(CFLAGS) -DLED_DELAY=$(LED_DELAY) $(LDFLAGS) -Wl,-Map,$(@:.elf=.map) start.S main.c -o $@

$(BUILD)/led_hw.elf: ../sim/programs/led.S linker.ld | $(BUILD) check-tools
	$(CC) $(ISA_FLAGS) -DLED_DELAY=$(LED_DELAY) $(LDFLAGS) -Wl,-Map,$(@:.elf=.map) $< -o $@

$(BUILD)/%.elf: ../sim/programs/%.S linker.ld | $(BUILD) check-tools
	$(CC) $(ISA_FLAGS) -DSIMULATION $(LDFLAGS) -Wl,-Map,$(@:.elf=.map) $< -o $@

$(BUILD)/%.mem: $(BUILD)/%.elf ../tools/check_isa.py ../tools/bin_to_mem.py
	$(OBJDUMP) -d -M no-aliases,numeric $< > $(@:.mem=.lst)
	$(OBJCOPY) -O binary --only-section=.text $< $(@:.mem=.text.bin)
	$(PYTHON) ../tools/check_isa.py $(@:.mem=.text.bin)
	$(OBJCOPY) -O binary $< $(@:.mem=.bin)
	$(PYTHON) ../tools/bin_to_mem.py $(@:.mem=.bin) $@
	$(SIZE) $<

# These committed fixtures make HDL tests independent of a local C compiler.
images: all
	cp $(PROGRAM_MEM) $(BUILD)/led_hw.mem ../sim/programs/
	cp $(BUILD)/firmware_sim.mem ../sim/programs/c_smoke.mem
	$(NM) -n $(BUILD)/firmware_sim.elf | awk \
	  '$$3 == "__bss_start" { start = $$1 } $$3 == "__bss_end" { end = $$1 } \
	   END { if (start == "" || end == "") exit 1; print start; print end }' \
	  > ../sim/programs/c_smoke.bss

clean:
	rm -rf $(BUILD)
