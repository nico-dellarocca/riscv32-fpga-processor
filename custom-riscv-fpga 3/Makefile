# Tang Nano 20K custom RV32I — software + HDL verification and FPGA build.
.DEFAULT_GOAL := help
SHELL := /bin/sh
FPGA_EXAMPLE ?= blink
DEVICE := GW2AR-LV18QN88C8/I7
FAMILY := GW2A-18C
BUILD := build/$(FPGA_EXAMPLE)
SOC_RTL := rtl/cpu/rv32i_core.v rtl/soc/rv32_soc.v rtl/top/tangnano20k_top.v

ifeq ($(FPGA_EXAMPLE),blink)
RTL := examples/01_blink/blink.v
TOP := blink
CST := examples/01_blink/tangnano20k.cst
else ifeq ($(FPGA_EXAMPLE),button)
RTL := examples/02_button_led/button_led.v
TOP := button_led
CST := examples/02_button_led/tangnano20k.cst
else ifeq ($(FPGA_EXAMPLE),soc)
RTL := $(SOC_RTL)
TOP := tangnano20k_top
CST := rtl/top/tangnano20k.cst
else
$(error Unknown FPGA_EXAMPLE $(FPGA_EXAMPLE): use blink, button, or soc)
endif

.PHONY: help firmware verify test check soc bitstream program-soc blink button program-blink program-button tools clean
help:
	@echo 'make verify        Compile RV32I firmware; run independent interpreter + Python unit tests'
	@echo 'make test          Run verify, then Icarus HDL simulations + instruction trace comparison'
	@echo 'make check         All checks: repository hygiene and make test (requires Icarus)'
	@echo 'make soc           Synthesize/place/route/pack full SoC for Tang Nano 20K'
	@echo 'make program-soc   Load SoC bitstream to FPGA SRAM (requires connected board)'
	@echo 'make blink         Build the historical FPGA LED example'
	@echo 'make button        Build the button-to-LED example'
	@echo 'make tools         Show hardware toolchain versions'
	@echo 'make clean         Remove generated build artifacts'

firmware:
	$(MAKE) -C software all
	$(MAKE) -C sim/programs all

verify: firmware
	python3 -m unittest discover -s scripts -p 'test_*.py' -v
	python3 -m unittest discover -s tests -p 'test_*.py' -v
	python3 scripts/rv32i_ref.py --image software/build/smoke.hex --mode signature
	python3 scripts/rv32i_ref.py --image sim/build/programs/isa.hex --mode signature
	python3 scripts/rv32i_ref.py --image software/build/gpio_fast.hex --mode gpio

test: verify
	python3 scripts/run_hdl.py

check:
	python3 scripts/check_repo.py
	$(MAKE) test

# The first two exercises can still be synthesized independently.
# Full SoC firmware is compiled before synthesis when selecting soc.
ifeq ($(FPGA_EXAMPLE),soc)
$(BUILD)/synth.json: software/build/gpio_demo.hex $(RTL)
else
$(BUILD)/synth.json: $(RTL)
endif
	@mkdir -p $(BUILD)
	yosys -p 'read_verilog $(RTL); synth_gowin -top $(TOP) -family gw2a -json $@'

software/build/gpio_demo.hex: software/gpio_demo.c software/start.S software/linker.ld software/Makefile scripts/bin_to_mem.py
	$(MAKE) -C software build/gpio_demo.hex

$(BUILD)/pnr.json: $(BUILD)/synth.json $(CST)
	nextpnr-himbaechel --device $(DEVICE) --json $< --write $@ \
		--vopt family=$(FAMILY) --vopt cst=$(CST)

$(BUILD)/design.fs: $(BUILD)/pnr.json
	gowin_pack -d $(FAMILY) -o $@ $<

bitstream: $(BUILD)/design.fs
	@echo 'FPGA bitstream ready: $(BUILD)/design.fs (hardware not yet demonstrated)'

soc:
	$(MAKE) FPGA_EXAMPLE=soc bitstream

blink:
	$(MAKE) FPGA_EXAMPLE=blink bitstream

button:
	$(MAKE) FPGA_EXAMPLE=button bitstream

program: $(BUILD)/design.fs
	openFPGALoader -b tangnano20k $(BUILD)/design.fs

program-soc:
	$(MAKE) FPGA_EXAMPLE=soc program

program-blink:
	$(MAKE) FPGA_EXAMPLE=blink program

program-button:
	$(MAKE) FPGA_EXAMPLE=button program

tools:
	@for t in yosys nextpnr-himbaechel gowin_pack openFPGALoader iverilog vvp clang llvm-objcopy; do \
	  command -v $$t >/dev/null && command -v $$t || echo "missing: $$t"; \
	done

clean:
	rm -rf build
	$(MAKE) -C software clean
	$(MAKE) -C sim/programs clean
