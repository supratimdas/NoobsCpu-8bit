`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04.09.2026 15:42:16
// Design Name: 
// Module Name: tb_top
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


module tb_top(
    );
    
reg clk;
    reg [15:0] cycle_count; // 13 bits needed to hold up to 5000 (2^13 = 8192)
    wire reset_;
    // Initial block to setup starting values and run clock loop
    initial begin
        clk = 0;
        cycle_count = 0;
        
        $display("Starting clock generation for 15000 cycles...");
        
        // Loop for exactly 5000 full clock periods
        while (cycle_count < 15000) begin
            #5 clk = 1;  // High for 5ns
            #5 clk = 0;  // Low for 5ns (10ns period = 100MHz clock)
            cycle_count = cycle_count + 1;
        end

        $display("Finished 15000 cycles. Ending simulation.");
        $finish;
     end
     
     assign reset_ = (cycle_count < 100) ? 0 : 1;
     
    
    blinky_soc u_soc (
        .reset_(reset_),
        .clk(clk),
        .LED(),
        .uart_tx(),
        .VGA_R(),
        .VGA_B(),
        .VGA_G(),
        .VGA_HS(),
        .VGA_VS()
    );
endmodule
