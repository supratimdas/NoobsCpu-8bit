/*********************************************************** 
* File Name     : execute.v
* Description   :
* Organization  : NONE 
* Creation Date : 07-03-2020
* Last Modified : Saturday 07 March 2020 01:31:37 PM IST
* Author        : Supratim Das (supratimofficio@gmail.com)
************************************************************/ 

module execute(
    clk,            //<i
    reset_,         //<i

    tgt_addr,       //>o
    next_addr,      //<i
    
    execute_en,     //<i
    reg_src0_data,  //<i 
    reg_src1_data,  //<i 
    imm_data,       //<i
    dst_reg,        //<i
    reg_wr_data,    //>o
    reg_wr_sel,     //>o
    reg_wr_en,      //>o
    
    dst_addr,       //<i
    exec_ctrl,      //<i
    d_mem_addr,     //>o
    d_mem_data,     //<io>
    d_mem_en,       //>o
    d_mem_rd,       //>o
    d_mem_wr        //>o
);

    //IO ports
    input           clk;
    input           reset_;

    output [11:0]   tgt_addr;
    input [11:0]    next_addr;

    input           execute_en;
    input [7:0]     reg_src0_data;
    input [7:0]     reg_src1_data;
    input [7:0]     imm_data;

    input [2:0]     dst_reg;

    output [7:0]    reg_wr_data;
    output [2:0]    reg_wr_sel;
    output          reg_wr_en;
    
    input  [3:0]    exec_ctrl;
    input  [11:0]   dst_addr;
    output [11:0]   d_mem_addr;
    output [7:0]    d_mem_data;
    output          d_mem_en;
    output          d_mem_rd;
    output          d_mem_wr;

    //other implementation stuff here
endmodule
