IVERILOG ?= iverilog
VVP ?= vvp
MACROS ?=null
VERILOG_SOURCES := $(filter-out ds_top.v sine_stimulus_top.v tb_delta_sigma_dac_stream.v,$(wildcard *.v))
STREAM_TEST_SOURCES := tb_delta_sigma_dac_stream.v delta_sigma_dac_stream.v ds_top.v \
	audio_linear_interpolator.v delta_sigma_dac_16bit.v \
	pdm_to_pwm_transcoder_p_channel_high.v

.PHONY: all simulate clean

all: sine_stim_test delta_sigma_stream_test

sine_stim_test: $(VERILOG_SOURCES)
	$(IVERILOG) -D$(MACROS) -s tb_sine_stimulus -o sine_stim_test $(VERILOG_SOURCES)

delta_sigma_stream_test: $(STREAM_TEST_SOURCES) sine_stimulus_unsigned.hex
	$(IVERILOG) -g2012 -s tb_delta_sigma_dac_stream -o delta_sigma_stream_test $(STREAM_TEST_SOURCES)

simulate: sine_stim_test delta_sigma_stream_test
	$(VVP) sine_stim_test
	$(VVP) delta_sigma_stream_test
#	gtkwave *.vcd

clean:
	rm -f sine_stim_test delta_sigma_stream_test
	rm -f *.vcd
