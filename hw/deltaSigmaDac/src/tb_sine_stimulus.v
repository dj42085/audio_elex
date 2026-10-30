`timescale 1ns / 1ps

module tb_sine_stimulus
    (
  `ifdef USE_NGSPICE
    input clk,
    input rst_n,
  `endif
    output dac_out,
    output pwm_high,
    output pwm_low,
    output pwm_n_high,
    output pwm_n_low,
    output sync_out
    );
    reg [15:0] stimulus_mem [0:88]; // Memory array for 89 samples
    reg [15:0] stimulus_out;        // Signal feeding into your DUT
    integer i;

`ifdef USE_NGSPICE
`else
    reg clk;
    reg rst_n;
    always #10 clk = ~clk;  // 50MHz clk for sigma delta
`endif
    reg sample_valid;
    wire [15:0] sample_out;
    reg [15:0] current_sample;
    reg [15:0] last_sample;

    audio_linear_interpolator ualin (.clk_50m(clk), .rst_n(rst_n), .sample_in(stimulus_out), 
                                     .sample_out(sample_out), .sample_valid(sample_valid));

    delta_sigma_dac_16bit udsdac (.clk(clk), .rst_n(rst_n), .dac_input(sample_out), .dac_out(dac_out));

    pdm_to_pwm_transcoder_p_channel_high upmwout (.clk_50m(clk), .rst_n(rst_n), .pdm_in(dac_out), .pwm_low(pwm_low), 
                                                  .pwm_high(pwm_high), .pwm_n_high(pwm_n_high), .pwm_n_low(pwm_n_low),
                                                  .sync_out(sync_out));

    initial begin
        $dumpfile("sine_test.vcd");
        $dumpvars(0, tb_sine_stimulus);
`ifndef USE_NGSPICE
        clk = 0;
        rst_n = 0;

        #50 rst_n = 1;
`endif

        // Load the hex file into the array
        $readmemh("sine_stimulus_unsigned.hex", stimulus_mem);
        
        stimulus_out = 16'h0000;
        
        // Wait for reset or initialization if your DUT needs it
       #100; 

        // Run all 89 samples once at a 44.1 kHz sampling rate
        for (i = 0; i < 89; i = i + 1) begin
            stimulus_out = stimulus_mem[i];
            #22676; // 1 / 44.1 kHz = ~22,675.73 ns
        end
        $finish;
    end

    always @ (posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        sample_valid <= 1'b0;
        current_sample <= 16'h0000;
        last_sample <= 16'h0000;
      end
      else begin
        current_sample <= stimulus_out;
        if (current_sample == last_sample) begin
           sample_valid <= 1'b0;
           last_sample <= current_sample;
        end
        else begin
           sample_valid <= 1'b1;
           last_sample <= current_sample;
        end
      end


    end

endmodule
