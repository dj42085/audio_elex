// -------------------------------------------------------------------------
// Module: pdm_to_pwm_transcoder
// Description: Transcodes a 50 MHz 1-bit PDM stream into a 300 kHz PWM signal.
//              50 MHz / 300 kHz = ~166 clock cycles per PWM frame window.
// -------------------------------------------------------------------------
module pdm_to_pwm_transcoder (
    input  wire       clk_50m,    // 50 MHz Master System Clock
    input  wire       rst_n,      // Active-low asynchronous reset
    input  wire       pdm_in,     // 1-bit PDM stream from Sigma-Delta loop
    output reg        pwm_out     // 300 kHz PWM output to AO3400 gate stage
);

    // Target window size: 50,000,000 / 300,000 = 166.66. 
    // We truncate to 166 cycles to keep precise synchronous timing.
    localparam [7:0] WINDOW_SIZE = 8'd166;

    // Registers for window timing and accumulation
    reg [7:0] cycle_counter;     // Tracks the current cycle within the 166 window
    reg [7:0] pdm_ones_accumulator; // Accumulates the number of '1's in the current window
    reg [7:0] active_duty_cycle; // Holds the duty cycle value for the active PWM generation

    // ---------------------------------------------------------------------
    // Step 1: PDM Window Profiler (Averages the high-speed bitstream)
    // ---------------------------------------------------------------------
    always @(posedge clk_50m or negedge rst_n) begin
        if (!rst_n) begin
            cycle_counter        <= 8'd0;
            pdm_ones_accumulator <= 8'd0;
            active_duty_cycle    <= 8'd83; // Default to 50% duty cycle (idle state)
        end else begin
            // Accumulate '1' bits from the high-speed PDM line
            if (pdm_in) begin
                pdm_ones_accumulator <= pdm_ones_accumulator + 1'b1;
            end

            // Check if we reached the end of our 300 kHz window (166 cycles)
            if (cycle_counter == (WINDOW_SIZE - 1'b1)) begin
                cycle_counter <= 8'd0;
                
                // Latch the accumulated value to drive the NEXT PWM frame
                active_duty_cycle <= pdm_ones_accumulator;
                
                // Reset accumulator for the upcoming window
                pdm_ones_accumulator <= 8'd0;
            end else begin
                cycle_counter <= cycle_counter + 1'b1;
            end
        end
    end

    // ---------------------------------------------------------------------
    // Step 2: PWM Output Generator (Maps the profile to pulse width)
    // ---------------------------------------------------------------------
    always @(posedge clk_50m or negedge rst_n) begin
        if (!rst_n) begin
            pwm_out <= 1'b0;
        end else begin
            // If our current position in the 166-cycle frame is less than 
            // the number of '1's counted in the previous frame, hold the output HIGH.
            if (cycle_counter < active_duty_cycle) begin
                pwm_out <= 1'b1;
            end else begin
                pwm_out <= 1'b0;
            end
        end
    end

endmodule

