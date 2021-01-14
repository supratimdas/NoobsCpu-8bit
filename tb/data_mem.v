/*********************************************************** 
* File Name     : data_mem.v
* Organization  : NONE
* Creation Date : 02-01-2021
* Last Modified : Thursday 14 January 2021 10:36:32 PM IST
* Author        : Supratim Das (supratimofficio@gmail.com)
************************************************************/ 
`timescale 1ns/1ps

/*=============Description======================
 *
 * simple ram model, to be used both as 
 * program/data memory, testbench
 *
 * ============================================*/


 module data_mem (
    clk,

    data,         //< io >
    addr,         //< i
    rd,           //< i
    wr,           //< i
    en            //< i

 );

    //IOs
    input            clk;

    inout [7:0]      data;
    input [11:0]     addr;
    input            rd;
    input            wr;
    input            en;


    //define the sram structure here
    reg [7:0]    mem [0:4095];

    wire [7:0]    r_data;

    always @(posedge clk) begin
        if(en & wr) begin
            mem[addr] <= data;
        end
    end

    assign r_data[7:0] = mem[addr];

    assign data[7:0] = (en & rd) ? r_data[7:0] : 8'bzzzz_zzzz;
 endmodule
