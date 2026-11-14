VERILATOR ?= verilator
NGSPICE ?= ngspice
CC ?= cc
DEBUG ?= 0

SPICE_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
REPO_ROOT := $(abspath $(SPICE_DIR)/../../..)
RTL_DIR := $(REPO_ROOT)/hw/deltaSigmaDac/src
HELIX_DIR := $(REPO_ROOT)/soc/demo/helix_mp3/src
MP3_FILE ?= $(REPO_ROOT)/soc/prog/crickets_clipped.mp3
VCD_FILE ?=
MACROS ?= null
VECTOR_FILE := $(SPICE_DIR)/mp3_1s.vec
BUILD_DIR := $(SPICE_DIR)/build/mp3_verilator$(if $(filter 1,$(DEBUG)),_debug)
HELIX_OBJ_DIR := $(BUILD_DIR)/helix
VERILATOR_DIR := $(BUILD_DIR)/obj_dir
SIMULATOR := $(VERILATOR_DIR)/Vdelta_sigma_dac_stream

HELIX_SOURCES := $(wildcard $(HELIX_DIR)/*.c \
	$(HELIX_DIR)/libhelix/*.c $(HELIX_DIR)/libhelix/real/*.c)
HELIX_OBJECTS := $(patsubst $(HELIX_DIR)/%.c,$(HELIX_OBJ_DIR)/%.o,$(HELIX_SOURCES))
RTL_SOURCES := $(RTL_DIR)/delta_sigma_dac_stream.v \
	$(RTL_DIR)/ds_top.v $(RTL_DIR)/audio_linear_interpolator.v \
	$(RTL_DIR)/delta_sigma_dac_16bit.v \
	$(RTL_DIR)/pdm_to_pwm_transcoder_p_channel_high.v

.PHONY: all mp3-vector ngspice-test clean
.PHONY: debug-build

all: ngspice-test
debug-build: $(SIMULATOR)

$(HELIX_OBJ_DIR)/%.o: $(HELIX_DIR)/%.c
	mkdir -p "$(@D)"
	$(CC) -O3 -std=gnu99 -I$(HELIX_DIR) \
		-I$(HELIX_DIR)/libhelix/pub -I$(HELIX_DIR)/libhelix/real \
		-c "$<" -o "$@"

$(SIMULATOR): $(RTL_SOURCES) mp3_verilator.cpp $(HELIX_OBJECTS)
	$(VERILATOR) --cc --exe --build -Wno-fatal --trace \
		$(if $(filter 1,$(DEBUG)),-MAKEFLAGS OPT_FAST=-O0) \
		--top-module delta_sigma_dac_stream \
		--Mdir "$(VERILATOR_DIR)" \
		-CFLAGS "$(if $(filter 1,$(DEBUG)),-g -O0 -D$(MACROS)) -std=c++17 -I$(HELIX_DIR) -I$(HELIX_DIR)/libhelix/pub -I$(HELIX_DIR)/libhelix/real" \
		$(RTL_SOURCES) "$(SPICE_DIR)/mp3_verilator.cpp" $(HELIX_OBJECTS)

mp3-vector: $(SIMULATOR)
	"$(SIMULATOR)" "$(MP3_FILE)" "$(VECTOR_FILE)" $(if $(VCD_FILE),"$(VCD_FILE)")

ngspice-test: mp3-vector
	cd "$(SPICE_DIR)" && $(NGSPICE) -b mp3_2ms.cir

clean:
	rm -rf "$(BUILD_DIR)" "$(VECTOR_FILE)" "$(SPICE_DIR)/mp3_2ms.raw" *.vcd *.vec
