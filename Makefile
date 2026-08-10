SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help
.DELETE_ON_ERROR:

ROOT := $(abspath $(dir $(firstword $(MAKEFILE_LIST))))
COMMON_ROOT ?= $(abspath $(ROOT)/../common)
BUILD_DIR ?= $(ROOT)/build
IVERILOG ?= iverilog
VVP ?= vvp
VERILATOR ?= verilator
VERIBLE_FORMAT ?= verible-verilog-format
CLANG_FORMAT ?= clang-format-14
HOST_CC ?= cc
PYTHON ?= python3
SBY ?= sby
SV2V ?= sv2v

RTL_SRCS := rtl/rtc_pkg.sv rtl/rtc_tickgen.sv rtl/rtc_core.sv rtl/rtc_reg.sv \
	rtl/rtc_if.sv rtl/apb4_rtc.sv
RTL_HDRS := rtl/rtc_define.svh
C_SRCS := sw/src/rtc.c sw/tests/test_rtc.c
C_HDRS := sw/include/rtc.h sw/include/rtc_regs.h
DV_SRCS := dv/unit/rtc_tb.sv dv/unit/apb4_rtc_tb.sv

COMMON_REGISTER := $(COMMON_ROOT)/rtl/utils/register.sv
COMMON_APB := $(COMMON_ROOT)/rtl/interface/apb4_if.sv
COMMON_CDC := $(COMMON_ROOT)/rtl/cdc/cdc_sync.sv \
	$(COMMON_ROOT)/rtl/cdc/cdc_rst_ctrlr.sv \
	$(COMMON_ROOT)/rtl/cdc/async_reqack.sv \
	$(COMMON_ROOT)/rtl/clkrst/rst_sync.sv
COMMON_INCLUDES := -Irtl -I$(COMMON_ROOT)/rtl -I$(COMMON_ROOT)/rtl/utils \
	-I$(COMMON_ROOT)/rtl/cdc -I$(COMMON_ROOT)/rtl/clkrst \
	-I$(COMMON_ROOT)/rtl/interface
CORE_SRCS := $(COMMON_REGISTER) rtl/rtc_pkg.sv rtl/rtc_tickgen.sv rtl/rtc_core.sv
IVERILOG_OUT := $(BUILD_DIR)/iverilog/rtc_tb.vvp
VERILATOR_DIR := $(BUILD_DIR)/verilator
APB_VERILATOR_DIR := $(BUILD_DIR)/apb-verilator
HOST_TEST := $(BUILD_DIR)/host/test_rtc

.PHONY: help doctor format format-check register-check lint test test-iverilog \
	test-verilator test-apb-verilator test-host synth formal clean

help:
	@printf '%s\n' \
	  'rtc targets:' \
	  '  doctor          verify required tools and Common checkout' \
	  '  format-check    verify SystemVerilog and C formatting' \
	  '  register-check  compare hand-written RTL and C offsets' \
	  '  lint            run Verilator lint' \
	  '  test            run Icarus, Verilator, and host C tests' \
	  '  synth           synthesize the RTC core with Yosys' \
	  '  formal          prove RTC core properties with SBY/Bitwuzla'

doctor:
	@for tool in $(IVERILOG) $(VVP) $(VERILATOR) $(VERIBLE_FORMAT) $(CLANG_FORMAT) \
		$(HOST_CC) $(PYTHON) yosys $(SBY) $(SV2V) bitwuzla; do \
		command -v $$tool >/dev/null || { echo "missing tool: $$tool" >&2; exit 1; }; \
	done
	@test -f $(COMMON_APB) || { echo "missing Common checkout: $(COMMON_ROOT)" >&2; exit 1; }

format:
	$(VERIBLE_FORMAT) --flagfile=$(ROOT)/.verible-format --inplace $(RTL_SRCS) $(RTL_HDRS) \
		$(DV_SRCS) formal/rtc_formal.sv
	$(CLANG_FORMAT) -i $(C_SRCS) $(C_HDRS)

format-check:
	@set -e; for file in $(RTL_SRCS) $(RTL_HDRS) $(DV_SRCS) formal/rtc_formal.sv; do \
		tmp=$$(mktemp); $(VERIBLE_FORMAT) --flagfile=$(ROOT)/.verible-format $$file > $$tmp; \
		cmp -s $$file $$tmp || { \
			echo "SystemVerilog format mismatch: $$file" >&2; rm -f $$tmp; exit 1; }; rm -f $$tmp; \
	done
	@set -e; for file in $(C_SRCS) $(C_HDRS); do \
		tmp=$$(mktemp); $(CLANG_FORMAT) $$file > $$tmp; cmp -s $$file $$tmp || { \
			echo "C format mismatch: $$file" >&2; rm -f $$tmp; exit 1; }; rm -f $$tmp; \
	done

register-check:
	$(PYTHON) scripts/check_register_parity.py

lint:
	$(VERILATOR) --lint-only --timing -Wall -Wno-fatal -Wno-DECLFILENAME \
		-Wno-UNDRIVEN -Wno-UNUSEDSIGNAL -DSV_ASSRT_DISABLE --top-module apb4_rtc \
		$(COMMON_INCLUDES) $(COMMON_APB) $(COMMON_REGISTER) $(COMMON_CDC) $(RTL_SRCS)

$(IVERILOG_OUT): $(CORE_SRCS) $(RTL_HDRS) dv/unit/rtc_tb.sv
	@mkdir -p $(@D)
	$(IVERILOG) -g2012 -DSV_ASSRT_DISABLE $(COMMON_INCLUDES) -s rtc_tb -o $@ \
		$(CORE_SRCS) dv/unit/rtc_tb.sv

test-iverilog: $(IVERILOG_OUT)
	$(VVP) $(IVERILOG_OUT) | tee $(BUILD_DIR)/iverilog/test.log
	@grep -q RTC_TEST_PASS $(BUILD_DIR)/iverilog/test.log

test-verilator:
	@mkdir -p $(VERILATOR_DIR) $(BUILD_DIR)/ccache-tmp $(BUILD_DIR)/tmp
	CCACHE_DISABLE=1 CCACHE_TEMPDIR=$(BUILD_DIR)/ccache-tmp TMPDIR=$(BUILD_DIR)/tmp \
	$(VERILATOR) --binary --timing -Wall -Wno-fatal -Wno-DECLFILENAME \
		-Wno-TIMESCALEMOD \
		-DSV_ASSRT_DISABLE --Mdir $(VERILATOR_DIR) --top-module rtc_tb \
		$(COMMON_INCLUDES) $(CORE_SRCS) dv/unit/rtc_tb.sv
	$(VERILATOR_DIR)/Vrtc_tb | tee $(VERILATOR_DIR)/test.log
	@grep -q RTC_TEST_PASS $(VERILATOR_DIR)/test.log

test-apb-verilator:
	@mkdir -p $(APB_VERILATOR_DIR) $(BUILD_DIR)/ccache-tmp $(BUILD_DIR)/tmp
	CCACHE_DISABLE=1 CCACHE_TEMPDIR=$(BUILD_DIR)/ccache-tmp TMPDIR=$(BUILD_DIR)/tmp \
	$(VERILATOR) --binary --timing -Wall -Wno-fatal -Wno-DECLFILENAME \
		-Wno-TIMESCALEMOD -Wno-UNUSEDSIGNAL -DSV_ASSRT_DISABLE --Mdir $(APB_VERILATOR_DIR) \
		--top-module apb4_rtc_tb $(COMMON_INCLUDES) $(COMMON_APB) $(COMMON_REGISTER) \
		$(COMMON_CDC) $(RTL_SRCS) dv/unit/apb4_rtc_tb.sv
	$(APB_VERILATOR_DIR)/Vapb4_rtc_tb | tee $(APB_VERILATOR_DIR)/test.log
	@grep -q RTC_APB_ASYNC_TEST_PASS $(APB_VERILATOR_DIR)/test.log

$(HOST_TEST): $(C_SRCS) $(C_HDRS)
	@mkdir -p $(@D)
	$(HOST_CC) -std=c11 -Wall -Wextra -Werror -pedantic -Isw/include $(C_SRCS) -o $@

test-host: $(HOST_TEST)
	$(HOST_TEST)

test: test-iverilog test-verilator test-apb-verilator test-host

synth:
	@mkdir -p $(BUILD_DIR)/synth
	$(SV2V) --top rtc_core -DSV_ASSRT_DISABLE $(COMMON_INCLUDES) $(CORE_SRCS) \
		--write=$(BUILD_DIR)/synth/rtc_core.v
	yosys -p 'read_verilog $(BUILD_DIR)/synth/rtc_core.v; hierarchy -top rtc_core; proc; opt; check; stat' \
		| tee $(BUILD_DIR)/synth/yosys.log

formal:
	@mkdir -p $(BUILD_DIR)/formal-src
	$(SV2V) --top rtc_formal -DFORMAL -DSV_ASSRT_DISABLE $(COMMON_INCLUDES) \
		$(CORE_SRCS) formal/rtc_formal.sv --write=$(BUILD_DIR)/formal-src/rtc_formal.v
	$(SBY) -f -d $(BUILD_DIR)/formal formal/rtc.sby

clean:
	rm -rf $(BUILD_DIR)
