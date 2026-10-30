VIVADO ?= vivado
JOBS ?= 4
BUILD_DIR ?= build

PROJECT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SRC_DIR := $(PROJECT_DIR)/src
BIT_FILE := $(BUILD_DIR)/sine_stimulus_top.bit
RTL_SOURCES := $(filter-out $(SRC_DIR)/tb_sine_stimulus.v,$(wildcard $(SRC_DIR)/*.v))
MEM_FILE := $(SRC_DIR)/sine_stimulus_unsigned.hex
IP_FILE := $(PROJECT_DIR)/deltaSigmaDac.srcs/sources_1/ip/clk_wiz_0/clk_wiz_0.xci
XDC_FILE := $(PROJECT_DIR)/Arty-S7-50-Master.xdc
BUILD_SCRIPT := $(PROJECT_DIR)/scripts/build_bitstream.tcl
ABS_BUILD_DIR := $(abspath $(BUILD_DIR))
ABS_BIT_FILE := $(ABS_BUILD_DIR)/sine_stimulus_top.bit

.PHONY: all bitstream clean launch_interactive

all: bitstream

bitstream: $(BIT_FILE)

$(BIT_FILE): $(RTL_SOURCES) $(MEM_FILE) $(IP_FILE) $(XDC_FILE) $(BUILD_SCRIPT)
	mkdir -p "$(ABS_BUILD_DIR)"
	cd "$(PROJECT_DIR)" && "$(VIVADO)" -mode batch -nojournal -nolog \
		-source "$(BUILD_SCRIPT)" -tclargs "$(ABS_BUILD_DIR)" "$(JOBS)"

clean:
	rm -rf "$(ABS_BUILD_DIR)/vivado" "$(ABS_BIT_FILE)"

launch_interactive:
	cd "$(PROJECT_DIR)" && "$(VIVADO)" -mode tcl -nojournal -nolog \
		-tclargs "$(ABS_BUILD_DIR)" "$(JOBS)" -interactive