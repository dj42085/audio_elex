`timescale 1ns / 1ps

module tb_delta_sigma_dac_stream;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg test_mode = 1'b0;
    reg [15:0] stream_data = 16'h0000;
    reg stream_valid = 1'b0;
    wire stream_ready;
    integer rom_samples_seen = 0;

    always #10 clk = ~clk;

    delta_sigma_dac_stream #(
        .SAMPLE_PERIOD_CYCLES(4)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .test_mode(test_mode),
        .sample_data(stream_data),
        .sample_valid(stream_valid),
        .sample_ready(stream_ready),
        .dac_out(),
        .pwm_high(),
        .pwm_low(),
        .pwm_n_high(),
        .pwm_n_low(),
        .sync_out()
    );

    initial begin
        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        @(negedge clk);
        stream_data = 16'h1234;
        stream_valid = 1'b1;
        while (!stream_ready)
            @(negedge clk);
        @(posedge clk);
        #1;
        if (dut.u_ds_top.ualin.current_sample !== 16'h1234)
            $fatal(1, "Streaming sample was not forwarded");
        if (dut.u_ds_top.ualin.ramp_increment <= 0)
            $fatal(1, "Interpolation ramp increment was not calculated");

        @(negedge clk);
        stream_valid = 1'b0;
        if (stream_ready)
            $fatal(1, "Streaming interface did not pace input samples");
        test_mode = 1'b1;
        #1;
        if (stream_ready)
            $fatal(1, "ROM test mode did not disable streaming input");
        repeat (20) @(posedge clk);
        #1;
        if (dut.u_ds_top.ualin.sample_out == 16'h0000)
            $fatal(1, "Interpolation ramp did not advance");
        if (rom_samples_seen < 3)
            $fatal(1, "Expected at least 3 ROM samples, observed %0d", rom_samples_seen);

        @(negedge clk);
        test_mode = 1'b0;
        stream_data = 16'h5678;
        stream_valid = 1'b1;
        while (!stream_ready)
            @(negedge clk);
        @(posedge clk);
        #1;
        if (dut.u_ds_top.ualin.current_sample !== 16'h5678)
            $fatal(1, "Streaming did not resume after leaving test mode");
        $finish;
    end

    always @(posedge clk) begin
        #1;
        if (rst_n && test_mode && dut.u_ds_top.sample_valid) begin
            case (rom_samples_seen)
                0: if (dut.u_ds_top.sample_in !== 16'h8000)
                       $fatal(1, "Unexpected first ROM sample");
                1: if (dut.u_ds_top.sample_in !== 16'hA3FB)
                       $fatal(1, "Unexpected second ROM sample");
                2: if (dut.u_ds_top.sample_in !== 16'hC50F)
                       $fatal(1, "Unexpected third ROM sample");
                default: begin end
            endcase
            rom_samples_seen = rom_samples_seen + 1;
        end
    end
endmodule
