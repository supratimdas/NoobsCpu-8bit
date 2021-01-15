/*********************************************************** 
* File Name     : execute.v
* Description   : execute unit
* Organization  : NONE 
* Creation Date : 07-03-2020
* Last Modified : Friday 15 January 2021 10:07:18 PM IST
* Author        : Supratim Das (supratimofficio@gmail.com)
************************************************************/ 
`timescale 1ns/1ps

module execute(
    clk,            //<i
    reset_,         //<i

    tgt_addr,       //>o
    next_addr,      //<i
    
    execute_en,     //<i
    reg_src0_data,  //<i 
    reg_src1_data,  //<i 
    imm_data,       //<i
    imm_data_vld,   //<i
    dst_reg,        //<i
    reg_wr_data,    //>o
    reg_wr_sel,     //>o
    reg_wr_en,      //>o
    
    dst_addr,       //<i
    exec_ctrl,      //<i
    d_mem_addr,     //>o
    d_mem_data_in,  //<i
    d_mem_data_out, //>o
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
    input           imm_data_vld;

    input [2:0]     dst_reg;

    output reg [7:0]    reg_wr_data;
    output reg [2:0]    reg_wr_sel;
    output reg [0:0]    reg_wr_en;
    
    input  [3:0]        exec_ctrl;
    input  [11:0]       dst_addr;
    output [11:0]       d_mem_addr;
    output [7:0]        d_mem_data_out;
    input  [7:0]        d_mem_data_in;
    output              d_mem_en;
    output              d_mem_rd;
    output              d_mem_wr;

    wire [7:0] src0_data;
    wire [7:0] src1_data;

    assign d_mem_addr = dst_addr;

    reg [3:0] exec_ctrl_1D; //1 cycle delayed version, since register read/imm value takes 1 cycle

    //use 1 cycle delayed version of exec_ctrl, 1 cycle is required for register read/read from memory
    always @(posedge clk) begin
        if(!reset_) begin
            exec_ctrl_1D[3:0] <= `EXEC_NOP;
        end
        else begin
            exec_ctrl_1D[3:0] <= exec_ctrl;
        end
    end

    //src0 & src1 data (these are available +1 cycle after decode generates the selects)
    assign src0_data = reg_src0_data;
    assign src1_data = imm_data_vld ? imm_data : reg_src1_data; //immediate value will also be available in the next cycle since the immediate value is encoded in the next 8 bit of the original instruction

    //generate memory access control signals
    assign d_mem_rd = (exec_ctrl_1D[3:0] == `MEM_OPERATION_RD);
    assign d_mem_wr = (exec_ctrl_1D[3:0] == `MEM_OPERATION_WR);
    assign d_mem_en = (d_mem_wr || d_mem_rd);

    assign d_mem_data_out[7:0] = src0_data;

    //actual operation based on the encoded exec_ctrl info
    always @(*) begin
        reg_wr_data = 8'd0;
        reg_wr_en   = 1'b0;
        reg_wr_sel  = dst_reg;
        case(exec_ctrl_1D[3:0])
            `EXEC_NOP : begin
                if(`DEBUG_PRINT) $display("{EXEC_NOP:} ");
            end
            `ALU_OPERATION_ADD : begin
                if(`DEBUG_PRINT) $display("{ALU_OPERATION_ADD:} ");
                reg_wr_data = src0_data + src1_data;
                reg_wr_en = 1;
            end
            `ALU_OPERATION_SUB : begin
                if(`DEBUG_PRINT) $display("{ALU_OPERATION_SUB:} ");
                reg_wr_data = src0_data - src1_data;
                reg_wr_en = 1;
            end
            `ALU_OPERATION_OR : begin
                if(`DEBUG_PRINT) $display("{ALU_OPERATION_OR:} ");
                reg_wr_data = src0_data | src1_data;
                reg_wr_en = 1;
            end
            `ALU_OPERATION_AND : begin
                if(`DEBUG_PRINT) $display("{ALU_OPERATION_AND:} ");
                reg_wr_data = src0_data & src1_data;
                reg_wr_en = 1;
            end
            `ALU_OPERATION_XOR : begin
                if(`DEBUG_PRINT) $display("{ALU_OPERATION_XOR:} ");
                reg_wr_data = src0_data ^ src1_data;
                reg_wr_en = 1;
            end
            `MEM_OPERATION_RD : begin
                if(`DEBUG_PRINT) $display("{MEM_OPERATION_RD:} ");
                reg_wr_data = d_mem_data_in;
                reg_wr_en = 1;
            end
            `MEM_OPERATION_WR : begin
                if(`DEBUG_PRINT) $display("{MEM_OPERATION_WR:} ");
            end
            `CPU_OPERATION_JMP : begin
            end
            `CPU_OPERATION_CALL : begin
            end
            `CPU_OPERATION_RET : begin
            end
            `EXEC_IDLE : begin
            end
        endcase
    end
endmodule
