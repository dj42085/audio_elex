# MP3 DAC ngspice simulation

`make -C hw/deltaSigmaDac/spice` decodes the first 2 ms of
`soc/prog/crickets_clipped.mp3`
in memory with Helix, feeds the PCM samples into the DAC RTL in Verilator,
and writes the RTL output transitions to `spice/mp3_2ms.vec`. The ngspice
XSPICE `d_source` model reads that vector file and drives the DAC gate and
PDM signals into the analog output-stage test bench, producing
`spice/mp3_2ms.raw`.

Use another MP3 file with:

```sh
make -C hw/deltaSigmaDac/spice MP3_FILE=/absolute/path/to/audio.mp3
```

The generated vector file uses ngspice XSPICE `d_source` time/state/strength
rows and can also be included in another netlist through:

```spice
.model mp3_trace d_source(input_file="mp3_2ms.vec")
A_MP3 [dac_out pwm_high pwm_low pwm_n_high pwm_n_low sync_out] mp3_trace
```
