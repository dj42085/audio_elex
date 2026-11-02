`timescale 1ns / 1ps

module delta_sigma_dac_stream #(
    parameter ROM_FILE = "sine_stimulus_unsigned.hex",
    parameter integer SAMPLE_COUNT = 89,
    parameter integer SAMPLE_PERIOD_CYCLES = 1134
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        test_mode,
    input  wire [15:0] sample_data,
    input  wire        sample_valid,
    output wire        sample_ready,
    output wire        dac_out,
    output wire        pwm_high,
    output wire        pwm_low,
    output wire        pwm_n_high,
    output wire        pwm_n_low,
    output wire        sync_out
);
    localparam integer ADDR_WIDTH = (SAMPLE_COUNT > 1) ? $clog2(SAMPLE_COUNT) : 1;
    localparam [ADDR_WIDTH-1:0] LAST_SAMPLE_INDEX =
        SAMPLE_COUNT[ADDR_WIDTH-1:0] - 1'b1;

    reg [15:0] stimulus_mem [0:SAMPLE_COUNT-1];
    reg [15:0] rom_sample_data;
    reg [ADDR_WIDTH-1:0] sample_index;
    reg [31:0] sample_clock_count;
    reg rom_sample_valid;
    reg test_mode_d;

    wire [15:0] selected_sample_data;
    wire selected_sample_valid;

    assign sample_ready = rst_n && !test_mode &&
                          (sample_clock_count == SAMPLE_PERIOD_CYCLES - 1);
    assign selected_sample_data = test_mode ? rom_sample_data : sample_data;
    assign selected_sample_valid = test_mode
        ? rom_sample_valid
        : (sample_valid && sample_ready);

    initial begin
        $readmemh(ROM_FILE, stimulus_mem);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rom_sample_data <= 16'h0000;
            sample_index <= {ADDR_WIDTH{1'b0}};
            sample_clock_count <= 32'd0;
            rom_sample_valid <= 1'b0;
            test_mode_d <= 1'b0;
        end else if (test_mode != test_mode_d) begin
            test_mode_d <= test_mode;
            sample_index <= {ADDR_WIDTH{1'b0}};
            sample_clock_count <= 32'd0;
            rom_sample_valid <= 1'b0;
        end else if (test_mode) begin
            if (sample_clock_count == SAMPLE_PERIOD_CYCLES - 1) begin
                sample_clock_count <= 32'd0;
                rom_sample_data <= stimulus_mem[sample_index];
                rom_sample_valid <= 1'b1;
                if (sample_index == LAST_SAMPLE_INDEX)
                    sample_index <= {ADDR_WIDTH{1'b0}};
                else
                    sample_index <= sample_index + 1'b1;
            end else begin
                sample_clock_count <= sample_clock_count + 1'b1;
                rom_sample_valid <= 1'b0;
            end
        end else begin
            test_mode_d <= test_mode;
            if (sample_clock_count == SAMPLE_PERIOD_CYCLES - 1)
                sample_clock_count <= 32'd0;
            else
                sample_clock_count <= sample_clock_count + 1'b1;
            rom_sample_valid <= 1'b0;
        end
    end

    ds_top u_ds_top (
        .clk_50m(clk),
        .rst_n(rst_n),
        .sample_in(selected_sample_data),
        .sample_valid(selected_sample_valid),
        .dac_out(dac_out),
        .pwm_high(pwm_high),
        .pwm_low(pwm_low),
        .pwm_n_high(pwm_n_high),
        .pwm_n_low(pwm_n_low),
        .sync_out(sync_out)
    );
endmodule
