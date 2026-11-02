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
    wire clk_50m;
    wire rst_n;
    wire reset_n_unlocked;
    wire system_rst_n;
    wire clk_locked;

    reg [1:0] reset_sync;

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

    delta_sigma_dac_stream u_delta_sigma_dac_stream (
        .clk(clk_50m),
        .rst_n(system_rst_n),
        .test_mode(1'b1),
        .sample_data(16'h0000),
        .sample_valid(1'b0),
        .sample_ready(),
        .dac_out(dac_out),
        .pwm_high(pwm_high),
        .pwm_low(pwm_low),
        .pwm_n_high(pwm_n_high),
        .pwm_n_low(pwm_n_low),
        .sync_out(sync_out)
    );
endmodule
