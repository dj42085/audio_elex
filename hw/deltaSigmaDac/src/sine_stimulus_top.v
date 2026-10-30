module sine_stimulus_top (
    input  wire clk_12m,
    input  wire reset_button,
    output wire dac_out,
    output wire pwm_high,
    output wire pwm_low,
    output wire pwm_n_high,
    output wire pwm_n_low,
    output wire sync_out
);
    localparam integer SAMPLE_COUNT = 89;
    localparam integer SAMPLE_PERIOD_CYCLES = 1134;

    wire clk_50m;
    wire rst_n;
    wire reset_n_unlocked;
    wire system_rst_n;
    wire clk_locked;

    reg [1:0] reset_sync;

    reg [15:0] stimulus_mem [0:SAMPLE_COUNT-1];
    reg [15:0] sample_in;
    reg [6:0] sample_index;
    reg [31:0] sample_clock_count;
    reg sample_valid;

    assign rst_n = ~reset_button;

    clk_dsstim u_clk_dsstim_0 (
        .clk_in1(clk_12m),
        .resetn(rst_n),
        .clk_out1(clk_50m),
        .locked(clk_locked)
    );

    assign reset_n_unlocked = rst_n & clk_locked;
    assign system_rst_n = reset_sync[1];

    always @(posedge clk_50m or negedge reset_n_unlocked) begin
        if (!reset_n_unlocked)
            reset_sync <= 2'b00;
        else
            reset_sync <= {reset_sync[0], 1'b1};
    end

    initial begin
        $readmemh("sine_stimulus_unsigned.hex", stimulus_mem);
    end

    always @(posedge clk_50m or negedge system_rst_n) begin
        if (!system_rst_n) begin
            sample_in <= 16'h0000;
            sample_index <= 7'd0;
            sample_clock_count <= 32'd0;
            sample_valid <= 1'b0;
        end else if (sample_clock_count == SAMPLE_PERIOD_CYCLES - 1) begin
            sample_clock_count <= 32'd0;
            sample_in <= stimulus_mem[sample_index];
            sample_valid <= 1'b1;
            if (sample_index == SAMPLE_COUNT - 1)
                sample_index <= 7'd0;
            else
                sample_index <= sample_index + 1'b1;
        end else begin
            sample_clock_count <= sample_clock_count + 1'b1;
            sample_valid <= 1'b0;
        end
    end

    ds_top u_ds_top (
        .clk_50m(clk_50m),
        .rst_n(system_rst_n),
        .sample_in(sample_in),
        .sample_valid(sample_valid),
        .dac_out(dac_out),
        .pwm_high(pwm_high),
        .pwm_low(pwm_low),
        .pwm_n_high(pwm_n_high),
        .pwm_n_low(pwm_n_low),
        .sync_out(sync_out)
    );
endmodule
