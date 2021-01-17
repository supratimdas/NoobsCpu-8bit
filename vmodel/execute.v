/*********************************************************** 
* File Name     : execute.v
* Description   : execute unit
* Organization  : NONE 
* Creation Date : 07-03-2020
* Last Modified : Sunday 17 January 2021 08:23:19 PM IST
* Author        : Supratim Das (supratimofficio@gmail.com)
************************************************************/ 
`timescale 1ns/1ps

module execute(
    clk,            //<i
    reset_,         //<i
    cycle_counter,  //<i
    print_en,       //<i //for enabling prints

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
    d_mem_wr,       //>o

    pc_branch,      //>o

    sr              //>o
);

    //IO ports
    input           clk;
    input           reset_;
    input           print_en;
    input [31:0]     cycle_counter;

    input           execute_en;
    input [7:0]     reg_src0_data;
    input [7:0]     reg_src1_data;
    input [7:0]     imm_data;
    input           imm_data_vld;

    input [1:0]     dst_reg;

    output reg [7:0]    reg_wr_data;
    output reg [1:0]    reg_wr_sel;
    output reg [0:0]    reg_wr_en;
    
    input  [3:0]        exec_ctrl;
    input  [11:0]       dst_addr;
    output [11:0]       d_mem_addr;
    output [7:0]        d_mem_data_out;
    input  [7:0]        d_mem_data_in;
    output              d_mem_en;
    output              d_mem_rd;
    output              d_mem_wr;

    output [7:0]        sr;

    output              pc_branch;


    wire [7:0] src0_data;
    wire [7:0] src1_data;

    reg [7:0] sr;
    reg [7:0] sr_next;

    /****************************STATUS_REGISTER BIT MAP*******************************
    *|    7    |    6    |    5    |    4    |    3    |    2    |    1    |    0    |
    *+---------+---------+---------+---------+---------+---------+---------+---------+
    *|  RSVD   |  RSVD   |  RSVD   |  I/TRP  |    Z    |   NZ    | ST-OVF  |   OVF   |
    *+---------+---------+---------+---------+---------+---------+---------+---------+
    */

    reg z_flag;
    reg nz_flag;
    reg ovf_flag;

    assign d_mem_addr = dst_addr;

    reg [3:0] exec_ctrl_1D; //1 cycle delayed version, since register read/imm value takes 1 cycle
    reg       execute_en_1D;
    wire      pc_branch;

    assign pc_branch = (exec_ctrl[3:0] == `CPU_OPERATION_JMP) & execute_en;

    //use 1 cycle delayed version of exec_ctrl, 1 cycle is required for register read/read from memory
    always @(posedge clk) begin
        if(!reset_) begin
            exec_ctrl_1D[3:0] <= `EXEC_NOP;
            sr[7:0]           <= 8'd0;
            execute_en_1D     <= 1'b0;
        end
        else begin
            exec_ctrl_1D[3:0] <= exec_ctrl;
            execute_en_1D     <= execute_en;
            sr[7:0]           <= sr_next[7:0];
        end
    end

    //src0 & src1 data (these are available +1 cycle after decode generates the selects)
    assign src0_data = reg_src0_data;
    assign src1_data = imm_data_vld ? imm_data : reg_src1_data; //immediate value will also be available in the next cycle since the immediate value is encoded in the next 8 bit of the original instruction

    //generate memory access control signals
    assign d_mem_rd = (exec_ctrl_1D[3:0] == `MEM_OPERATION_RD) & execute_en_1D;
    assign d_mem_wr = (exec_ctrl_1D[3:0] == `MEM_OPERATION_WR) & execute_en_1D;
    assign d_mem_en = (d_mem_wr || d_mem_rd) & execute_en_1D;

    assign d_mem_data_out[7:0] = src0_data;

    //actual operation based on the encoded exec_ctrl info
    always @(*) begin
        reg_wr_data = 8'd0;
        reg_wr_en   = 1'b0;
        reg_wr_sel  = dst_reg;
        z_flag   = 1'b0;
        nz_flag  = 1'b0;
        ovf_flag = 1'b0;
        sr_next = sr;
        if(execute_en_1D) begin
            case(exec_ctrl_1D[3:0])
                `EXEC_NOP : begin
                    if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {EXEC_NOP:} ",cycle_counter);
                end
                `ALU_OPERATION_ADD : begin
                    if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {ALU_OPERATION_ADD:} ", cycle_counter);
                    {ovf_flag, reg_wr_data} = src0_data + src1_data;
                    z_flag = (reg_wr_data == 8'd0);
                    nz_flag = (reg_wr_data != 8'd0);
                    sr_next = {4'd0, z_flag, nz_flag, 1'b0, ovf_flag};
                    reg_wr_en = 1;
                end
                `ALU_OPERATION_SUB : begin
                    if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {ALU_OPERATION_SUB:} ", cycle_counter);
                    {ovf_flag, reg_wr_data} = src0_data - src1_data;
                    z_flag = (reg_wr_data == 8'd0);
                    nz_flag = (reg_wr_data != 8'd0);
                    sr_next = {4'd0, z_flag, nz_flag, 1'b0, ovf_flag};
                    reg_wr_en = 1;
                end
                `ALU_OPERATION_OR : begin
                    if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {ALU_OPERATION_OR:} ", cycle_counter);
                    reg_wr_data = src0_data | src1_data;
                    z_flag = (reg_wr_data == 8'd0);
                    nz_flag = (reg_wr_data != 8'd0);
                    sr_next = {4'd0, z_flag, nz_flag, 2'd0};
                    reg_wr_en = 1;
                end
                `ALU_OPERATION_AND : begin
                    if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {ALU_OPERATION_AND:} ", cycle_counter);
                    reg_wr_data = src0_data & src1_data;
                    z_flag = (reg_wr_data == 8'd0);
                    nz_flag = (reg_wr_data != 8'd0);
                    sr_next = {4'd0, z_flag, nz_flag, 2'd0};
                    reg_wr_en = 1;
                end
                `ALU_OPERATION_XOR : begin
                    if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {ALU_OPERATION_XOR:} ", cycle_counter);
                    reg_wr_data = src0_data ^ src1_data;
                    z_flag = (reg_wr_data == 8'd0);
                    nz_flag = (reg_wr_data != 8'd0);
                    sr_next = {4'd0, z_flag, nz_flag, 2'd0};
                    reg_wr_en = 1;
                end
                `MEM_OPERATION_RD : begin
                    if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {MEM_OPERATION_RD: reg[%d] <= %x} ",cycle_counter, reg_wr_sel, d_mem_data_in);
                    reg_wr_data = d_mem_data_in;
                    reg_wr_en = 1;
                end
                `MEM_OPERATION_WR : begin
                    if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {MEM_OPERATION_WR: %x => mem[%d] } ",cycle_counter, d_mem_data_out, d_mem_addr);
                end
                `CPU_OPERATION_JMP : begin
                    sr_next = {4'd0, z_flag, nz_flag, 1'b0, ovf_flag};
                end
                `CPU_OPERATION_CALL : begin
                    sr_next = {4'd0, z_flag, nz_flag, 1'b0, ovf_flag};
                end
                `CPU_OPERATION_RET : begin
                    sr_next = {4'd0, z_flag, nz_flag, 1'b0, ovf_flag};
                end
            endcase
        end
    end
endmodule
