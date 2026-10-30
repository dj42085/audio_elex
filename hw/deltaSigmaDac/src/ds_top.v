`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/25/2026 12:52:21 AM
// Design Name: 
// Module Name: ds_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ds_top(
        input wire clk_50m,
        input wire rst_n,
        input wire [15:0] sample_in,
        input wire sample_valid,
        output wire dac_out,
        output wire pwm_high,
        output wire pwm_low,
        output wire pwm_n_high,
        output wire pwm_n_low,
        output wire sync_out
    );

    wire [15:0] sample_out;

    audio_linear_interpolator ualin (
        .clk_50m(clk_50m),
        .rst_n(rst_n),
        .sample_in(sample_in),
        .sample_out(sample_out),
        .sample_valid(sample_valid)
    );

    delta_sigma_dac_16bit udsdac (
        .clk(clk_50m),
        .rst_n(rst_n),
        .dac_input(sample_out),
        .dac_out(dac_out)
    );

    pdm_to_pwm_transcoder_p_channel_high upmwout (
        .clk_50m(clk_50m),
        .rst_n(rst_n),
        .pdm_in(dac_out),
        .pwm_low(pwm_low),
        .pwm_high(pwm_high),
        .pwm_n_high(pwm_n_high),
        .pwm_n_low(pwm_n_low),
        .sync_out(sync_out)
    );

endmodule
