`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/25/2026 12:45:00 AM
// Design Name: 
// Module Name: audio_linear_interpolator
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


module audio_linear_interpolator (
    input  wire        clk_50m,     // 50 MHz system clock
    input  wire        rst_n,       // Active-low reset
    input  wire        sample_valid,// Pulsed HIGH for 1 clock cycle when a new 44.1kHz sample arrives
    input  wire [15:0] sample_in,   // 16-bit incoming audio data from minimp3
    output reg  [15:0] sample_out   // Smooth 16-bit output running at 50 MHz to the DAC
);

    // Local constants
    localparam [10:0] STEPS_PER_SAMPLE = 11'd1133;

    // The last input sample is the starting point for the next interpolation ramp.
    reg [15:0] current_sample;
    
    // Tracks our position between sample A and sample B (0 to 1132)
    reg [10:0] step_counter;
    
    // Fixed-point accumulation registers to track fractional increments
    reg signed [31:0] ramp_accumulator;
    reg signed [31:0] ramp_increment;
    wire signed [32:0] ramp_delta =
        $signed({1'b0, sample_in, 16'd0}) - $signed({1'b0, current_sample, 16'd0});

    // Capture incoming samples and handle the sample rate boundary
    always @(posedge clk_50m or negedge rst_n) begin
        if (!rst_n) begin
            current_sample   <= 16'd0;
            step_counter     <= 11'd0;
            ramp_accumulator <= 32'd0;
            ramp_increment   <= 32'd0;
        end else begin
            if (sample_valid) begin
                current_sample <= sample_in;

                // Reset the step tracker for the new sample window
                step_counter   <= 11'd0;
                
                // Start at the previous sample and ramp toward the new one.
                ramp_accumulator <= {current_sample, 16'd0};
                ramp_increment   <= ramp_delta / 33'sd1133;
                
            end else if (step_counter < STEPS_PER_SAMPLE - 1) begin
                step_counter     <= step_counter + 11'd1;
                // Add the pre-calculated step slope to move along the line
                ramp_accumulator <= ramp_accumulator + ramp_increment;
            end
        end
    end

    // Output the upper 16 bits of our fixed-point accumulator to the DAC
    always @(*) begin
        sample_out = ramp_accumulator[31:16];
    end

endmodule