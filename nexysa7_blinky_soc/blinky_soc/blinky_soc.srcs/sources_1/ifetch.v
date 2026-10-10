/*********************************************************** 
* File Name     : ifetch.v
* Description   : instruction fetch unit
* Organization  : NONE 
* Creation Date : 11-05-2019
* Last Modified : Sunday 06 February 2022 04:49:03 PM
* Author        : Supratim Das (supratimofficio@gmail.com)
************************************************************/ 
`timescale 1ns/1ps

//Short summary:
//this module implements the instruction fetch logic.
//this has the program_counter implementation
`include "noobs_cpu_defines.vh"

module ifetch(
    clk,        //< i
    reset_,     //< i
    branch,     //< i branch indication from ctrl unit
    ret_addr,   //<i    //return address
    ret_addr_en,//<i
    ifetch_en,  //< i ifetch_en indiaction from ctrl unit
    inst_i,     //< i instruction input from inst_mem
    tgt_addr,   //< i tgt branch addr
    inst_o,     //> o instruction output to decode unit
    idecode_en, //> o ifetch2idecode_en
    inst_addr,  //> o addr for instruction memory 
    next_addr   //>o next PC address
);
    //IOs
    input           clk;
    input           reset_;

    input           branch;
    input           ifetch_en;

    input [7:0]     inst_i;
    input [11:0]    tgt_addr;
    input [11:0]    ret_addr;
    input           ret_addr_en;

    output [7:0]    inst_o;
    output [11:0]   inst_addr;
    output [11:0]   next_addr;

    output          idecode_en;
    
    //regs
    reg [11:0]  PC;
    reg [7:0]   inst_reg;
    reg         idecode_en;

    //wires
    wire [11:0] pc_addr_next;
    wire [7:0] inst;

    //Program Counter implementation
    always @(posedge clk)   begin
        if(!reset_) begin
            PC[11:0]    <= 12'd0;
        end
        else begin
            PC[11:0]    <= pc_addr_next[11:0]; 
        end
    end

    wire [11:0] next_addr;
    assign next_addr = PC + 1'b1; 
    assign pc_addr_next = (ifetch_en) ? ((branch) ? (tgt_addr + 1'b1) : (ret_addr_en ? ret_addr : next_addr)) : PC;
    assign inst_addr = branch ? tgt_addr : PC;    //address for inst mem

    //registering instruction from instruction mem
    always @(posedge clk)   begin
        if(!reset_) begin
            inst_reg[7:0]   <= 8'd0;
            idecode_en      <= 1'b0;
        end
        else begin
            inst_reg[7:0]   <= inst;
            idecode_en      <= ifetch_en;
        end
    end

    assign inst[7:0] = (ifetch_en) ? inst_i[7:0] : inst_reg[7:0];

    assign inst_o[7:0] = inst_reg[7:0];
endmodule
