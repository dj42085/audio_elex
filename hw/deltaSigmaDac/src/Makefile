IVERILOG ?= iverilog
VVP ?= vvp
MACROS ?=
VERILOG_SOURCES := $(filter-out ds_top.v,$(wildcard *.v))

.PHONY: all simulate clean

all: sine_stim_test

sine_stim_test: $(VERILOG_SOURCES)
	$(IVERILOG) -D$(MACROS) -s tb_sine_stimulus -o sine_stim_test $(VERILOG_SOURCES)

simulate: sine_stim_test
	$(VVP) sine_stim_test
	gtkwave *.vcd

clean:
	rm -f sine_stim_test
