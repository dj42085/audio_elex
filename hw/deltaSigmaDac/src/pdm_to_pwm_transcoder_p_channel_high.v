// -------------------------------------------------------------------------
// Module: pdm_to_pwm_transcoder_p_channel_high
// Description: Transcodes a 50 MHz 1-bit PDM stream into a 300 kHz PWM signal,
//              then splits it into complementary High-Side and Low-Side signals.
//              Modded for an AO3401A P-Channel High-Side (Active-LOW Gate) 
//              and an AO3400 N-Channel Low-Side (Active-HIGH Gate).
// -------------------------------------------------------------------------
module pdm_to_pwm_transcoder_p_channel_high (
    input  wire       clk_50m,    // 50 MHz Master System Clock (20ns period)
    input  wire       rst_n,      // Active-low asynchronous reset
    input  wire       pdm_in,     // 1-bit PDM stream from Sigma-Delta loop
    output reg        pwm_high,   // High-Side Gate Drive (AO3401A P-Ch: Active-LOW)
    output reg        pwm_low     // Low-Side Gate Drive (AO3400 N-Ch: Active-HIGH)
);

    // Timing Parameters based on a 50 MHz Clock (1 cycle = 20ns)
    localparam [7:0] WINDOW_SIZE   = 8'd166; // 50 MHz / 300 kHz = ~166 cycles
    
    // Dead-Time Configuration:
    // 3 cycles * 20ns = 60ns of dead-time.
    // The AO3401A P-Ch has a max turn-off delay time of roughly 40-50ns. 
    // 60ns safely clears this window before the low-side turns on.
    localparam [3:0] DEAD_TIME_CYCLES = 4'd3; 

    // Registers for window timing and accumulation
    reg [7:0] cycle_counter;        // Tracks position in the 166-cycle frame
    reg [7:0] pdm_ones_accumulator; // Accumulates PDM '1's in current window
    reg [7:0] active_duty_cycle;    // Latched duty cycle value for active frame

    // Internal raw PWM signal before splitting
    reg pwm_raw;

    // Dead-time tracking counters
    reg [3:0] dt_counter_high;
    reg [3:0] dt_counter_low;

    // ---------------------------------------------------------------------
    // Step 1: PDM Window Profiler & Raw PWM Generation
    // ---------------------------------------------------------------------
    always @(posedge clk_50m or negedge rst_n) begin
        if (!rst_n) begin
            cycle_counter        <= 8'd0;
            pdm_ones_accumulator <= 8'd0;
            active_duty_cycle    <= 8'd83; // Default to 50% duty cycle
            pwm_raw              <= 1'b0;
        end else begin
            // Accumulate PDM bits
            if (pdm_in) begin
                pdm_ones_accumulator <= pdm_ones_accumulator + 1'b1;
            end

            // Check frame window boundary
            if (cycle_counter == (WINDOW_SIZE - 1'b1)) begin
                cycle_counter        <= 8'd0;
                active_duty_cycle    <= pdm_ones_accumulator;
                pdm_ones_accumulator <= 8'd0;
            end else begin
                cycle_counter        <= cycle_counter + 1'b1;
            end

            // Generate raw single-ended PWM pulse
            if (cycle_counter < active_duty_cycle) begin
                pwm_raw <= 1'b1;
            end else begin
                pwm_raw <= 1'b0;
            end
        end
    end

    // ---------------------------------------------------------------------
    // Step 2: Complementary Splitting with Inverted High-Side Logic
    // ---------------------------------------------------------------------
    always @(posedge clk_50m or negedge rst_n) begin
        if (!rst_n) begin
            pwm_high        <= 1'b1; // P-Channel Gate HIGH = OFF
            pwm_low         <= 1'b0; // N-Channel Gate LOW  = OFF
            dt_counter_high <= 4'd0;
            dt_counter_low  <= 4'd0;
        end else begin
            
            // --- HIGH-SIDE CONDITION (pwm_raw == 1) ---
            // High-side needs to be ON, Low-side needs to be OFF
            if (pwm_raw == 1'b1) begin
                pwm_low        <= 1'b0; // Turn off low-side instantly
                dt_counter_low <= 4'd0;
                
                // Wait for the High-Side dead-time delay to clear
                if (dt_counter_high < DEAD_TIME_CYCLES) begin
                    pwm_high        <= 1'b1; // Keep P-Ch OFF (Gate HIGH) during dead-time
                    dt_counter_high <= dt_counter_high + 1'b1;
                end else begin
                    pwm_high        <= 1'b0; // Safely turn ON P-Ch (Gate LOW)
                end
            end
            
            // --- LOW-SIDE CONDITION (pwm_raw == 0) ---
            // Low-side needs to be ON, High-side needs to be OFF
            else begin
                pwm_high        <= 1'b1; // Turn off high-side instantly (Gate HIGH)
                dt_counter_high <= 4'd0;
                
                // Wait for the Low-Side dead-time delay to clear
                if (dt_counter_low < DEAD_TIME_CYCLES) begin
                    pwm_low        <= 1'b0; // Keep N-Ch OFF (Gate LOW) during dead-time
                    dt_counter_low <= dt_counter_low + 1'b1;
                end else begin
                    pwm_low        <= 1'b1; // Safely turn ON N-Ch (Gate HIGH)
                end
            end
            
        end
    end

endmodule

