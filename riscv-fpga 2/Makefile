SHELL := /bin/bash
.DELETE_ON_ERROR:
IVERILOG ?= iverilog
VVP ?= vvp
YOSYS ?= yosys
PYTHON ?= python3
RISCV_PREFIX ?= riscv64-unknown-elf-
RTL = rtl/rv32i_core.v rtl/rv32_soc.v rtl/tangnano20k_top.v

.PHONY: help sim check-sim firmware images sim-firmware synth clean
help:
	@echo "make sim          Run directed RTL tests with checked-in program images"
	@echo "make firmware     Compile assembly and simulation/board C; check opcodes"
	@echo "make images       Regenerate checked-in RAM images and C .bss metadata"
	@echo "make sim-firmware Rebuild images, then simulate them"
	@echo "make synth        Gowin-targeted Yosys synthesis (no place/route/programming)"
	@echo "make clean        Remove generated build files"

check-sim:
	@command -v "$(IVERILOG)" >/dev/null 2>&1 || { echo "NOT RUN: iverilog unavailable"; exit 1; }
	@command -v "$(VVP)" >/dev/null 2>&1 || { echo "NOT RUN: vvp unavailable"; exit 1; }

build:
	mkdir -p build

build/tb_blink: examples/blink.v examples/tb_blink.v | build check-sim
	$(IVERILOG) -g2012 -Wall -s tb_blink -o $@ $^
build/tb_cpu: rtl/rv32i_core.v sim/tb_cpu.v | build check-sim
	$(IVERILOG) -g2012 -Wall -s tb_cpu -o $@ $^
build/tb_soc: rtl/rv32i_core.v rtl/rv32_soc.v sim/tb_soc.v | build check-sim
	$(IVERILOG) -g2012 -Wall -s tb_soc -o $@ $^
build/tb_top: $(RTL) sim/tb_top.v | build check-sim
	$(IVERILOG) -g2012 -Wall -s tb_top -o $@ $^

sim: check-sim build/tb_blink build/tb_cpu build/tb_soc build/tb_top
	@set -o pipefail; $(VVP) build/tb_blink | tee build/blink.log
	@set -o pipefail; $(VVP) build/tb_cpu | tee build/cpu.log
	@set -o pipefail; $(VVP) build/tb_soc | tee build/soc.log
	@set -o pipefail; $(VVP) build/tb_top | tee build/top.log

firmware:
	$(MAKE) -C software all RISCV_PREFIX="$(RISCV_PREFIX)" PYTHON="$(PYTHON)"
images:
	$(MAKE) -C software images RISCV_PREFIX="$(RISCV_PREFIX)" PYTHON="$(PYTHON)"
sim-firmware:
	$(MAKE) images
	$(MAKE) sim

# Synthesis establishes a netlist and RAM mapping only. A placed-and-routed
# 27 MHz timing report and successful board programming remain separate gates.
synth: | build
	@command -v "$(YOSYS)" >/dev/null 2>&1 || { echo "NOT RUN: yosys unavailable; configure Yosys with Gowin support"; exit 1; }
	@test -f sim/programs/led_hw.mem || { echo "NOT RUN: board image missing; run make images"; exit 1; }
	$(YOSYS) -l build/synth.log -p 'read_verilog $(RTL); synth_gowin -family gw2a -top tangnano20k_top -json build/soc.json; check; stat'

clean:
	rm -rf build
