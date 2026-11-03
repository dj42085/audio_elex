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

    // Three calculation cycles leave 1130 clocks to complete each ramp.
    localparam [10:0] RAMP_DIVISOR = 11'd1130;

    // The last input sample is the starting point for the next interpolation ramp.
    reg [15:0] current_sample;
    
    // Tracks our position between sample A and sample B (0 to 1130)
    reg [10:0] step_counter;
    
    // Fixed-point accumulation registers to track fractional increments
    reg signed [31:0] ramp_accumulator;
    reg signed [31:0] ramp_increment;
    wire signed [16:0] ramp_delta =
        $signed({1'b0, sample_in}) - $signed({1'b0, current_sample});

    reg signed [16:0] delta_stage;
    reg signed [6:0] whole_steps_stage;
    reg signed [11:0] remainder_stage;
    reg signed [6:0] whole_steps_final;
    reg signed [16:0] fraction_final;
    reg [2:0] slope_valid;
    wire signed [16:0] whole_steps_computed;
    wire signed [16:0] remainder_computed;
    wire signed [27:0] fraction_computed;

    assign whole_steps_computed =
        delta_stage / $signed({6'd0, RAMP_DIVISOR});
    assign remainder_computed =
        delta_stage % $signed({6'd0, RAMP_DIVISOR});
    assign fraction_computed =
        $signed({remainder_stage, 16'b0}) /
        $signed({17'd0, RAMP_DIVISOR});

    // Capture incoming samples and handle the sample rate boundary
    always @(posedge clk_50m or negedge rst_n) begin
        if (!rst_n) begin
            current_sample   <= 16'd0;
            step_counter     <= 11'd0;
            ramp_accumulator <= 32'd0;
            ramp_increment   <= 32'd0;
            delta_stage      <= 17'sd0;
            whole_steps_stage <= 7'sd0;
            remainder_stage   <= 12'sd0;
            whole_steps_final <= 7'sd0;
            fraction_final    <= 17'sd0;
            slope_valid       <= 3'b000;
        end else begin
            slope_valid <= {slope_valid[1:0], sample_valid};

            if (sample_valid)
                delta_stage <= ramp_delta;

            if (slope_valid[0]) begin
                whole_steps_stage <= whole_steps_computed[6:0];
                remainder_stage   <= remainder_computed[11:0];
            end

            if (slope_valid[1]) begin
                whole_steps_final <= whole_steps_stage;
                fraction_final <= fraction_computed[16:0];
            end

            if (slope_valid[2]) begin
                ramp_increment <=
                    $signed({{9{whole_steps_final[6]}}, whole_steps_final, 16'b0}) +
                    $signed({{15{fraction_final[16]}}, fraction_final});
            end

            if (sample_valid) begin
                current_sample <= sample_in;

                // Reset the step tracker for the new sample window
                step_counter   <= 11'd0;
                
                // Start at the previous sample and ramp toward the new one.
                ramp_accumulator <= {current_sample, 16'd0};
            end else if (|slope_valid) begin
                // Hold the starting sample until its new slope is available.
            end else if (step_counter == RAMP_DIVISOR) begin
                // Once we reach the end of the ramp, hold the last sample value
                ramp_accumulator <= {sample_in, 16'd0};
                
            end else if (step_counter < RAMP_DIVISOR) begin
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
