`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/25/2026 12:38:04 AM
// Design Name: 
// Module Name: delta_sigma_dac_16bit
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


module delta_sigma_dac_16bit(
    input  wire        clk,        // High-speed clock`
    input  wire        rst_n,      
    input  wire [15:0] dac_input,  // Expanded to 16-bit input`
    output reg         dac_out    
);
    // Accumulator must be 1 bit wider than the input data`
    reg [16:0] accumulator; 

    always @(posedge clk or negedge rst_n) begin
       if (!rst_n) begin
            accumulator <= 17'd0;
            dac_out     <= 1'b0;        
            end else begin
            accumulator <= accumulator[15:0] + dac_input;
            dac_out     <= accumulator[16]; // Use MSB (bit 16) as output`
        end
    end
endmodule
