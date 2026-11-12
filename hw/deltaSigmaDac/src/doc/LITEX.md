# LiteX integration

`delta_sigma_dac_stream` is the reusable DAC wrapper. Add
`delta_sigma_dac_stream.v`, `ds_top.v`, `audio_linear_interpolator.v`,
`delta_sigma_dac_16bit.v`, and `pdm_to_pwm_transcoder_p_channel_high.v` to
the LiteX platform sources, then instantiate the wrapper in a 50 MHz clock
domain. The PWM and interpolation timing in this design assumes 50 MHz.

Connect a one-bit LiteX CSR field to `test_mode`, and connect the LiteX
stream's `data`, `valid`, and `ready` signals to `sample_data`,
`sample_valid`, and `sample_ready`. The CSR field must be in the DAC clock
domain. Set `test_mode=0` for streaming and `test_mode=1` for the sine test.

The Arty S7 audio SoC exposes the DAC stream to firmware with `dac_sample_data`
and `dac_sample_ready` CSRs. Firmware should poll `dac_sample_ready` before
writing each unsigned PCM sample to `dac_sample_data`. A 256-sample system
clock-domain FIFO buffers writes before the stream crosses into the DAC clock
domain.

Samples are unsigned 16-bit values. The input is an unbuffered ready/valid
interface; `sample_ready` pulses once every `SAMPLE_PERIOD_CYCLES` clocks and
accepts a sample on that clock when `sample_valid` is asserted. Keep
`sample_valid` and `sample_data` stable until the handshake. The default
cadence is about 44.1 kHz at 50 MHz.

The wrapper always loads `ROM_FILE` (default `sine_stimulus_unsigned.hex`)
and repeats the configured `SAMPLE_COUNT` entries at intervals of
`SAMPLE_PERIOD_CYCLES` clocks while `test_mode` is asserted. The ROM address
and sample cadence restart when the mode changes. In test mode `sample_ready`
is low and streaming input is ignored. Ensure the hex file is included as a
memory initialization file and available at the path specified by `ROM_FILE`
in the FPGA build.

`rst_n` is active-low. LiteX designs with active-high reset signals should
connect the inverted reset for the current clock domain.
