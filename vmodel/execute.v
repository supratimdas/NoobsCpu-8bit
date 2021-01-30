/*********************************************************** 
* File Name     : execute.v
* Description   : execute unit
* Organization  : NONE 
* Creation Date : 07-03-2020
* Last Modified : Sunday 31 January 2021 12:14:45 AM IST
* Author        : Supratim Das (supratimofficio@gmail.com)
************************************************************/ 
`timescale 1ns/1ps

module execute(
    clk,            //<i
    reset_,         //<i
    cycle_counter,  //<i
    print_en,       //<i //for enabling prints
    latch_ret_addr, //<i //latching return address    
    sp_msb_10_8,    //>i    //stack pointer msb 10-8

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
    d_mem_wr,       //>o

    pc_branch,      //>o
    ret_addr,       //>o    //return address
    ret_addr_en,    //>o

    status_reg      //>o
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
    input           latch_ret_addr;

    input [2:0]     sp_msb_10_8;

    output reg [7:0]    reg_wr_data;
    output reg [1:0]    reg_wr_sel;
    output reg [0:0]    reg_wr_en;
    
    input  [3:0]        exec_ctrl;
    input  [11:0]       dst_addr;
    input  [11:0]       next_addr;
    output [11:0]       d_mem_addr;
    output [7:0]        d_mem_data_out;
    input  [7:0]        d_mem_data_in;
    output              d_mem_en;
    output              d_mem_rd;
    output              d_mem_wr;

    output [7:0]        status_reg;

    output              pc_branch;
    output [11:0]       ret_addr;
    output              ret_addr_en;


    wire [7:0] src0_data;
    wire [7:0] src1_data;

    reg [7:0] sr;
    reg [7:0] sr_next;
    wire [7:0] status_reg;

    reg  [7:0] ret_addr0;
    reg  [7:0] ret_addr1;
    reg  store_ret_addr_lower;
    reg  store_ret_addr_upper;

    reg  [7:0] sp_lsb_7_0; //lower 8 bit of stack pointer
    reg  [7:0] sp_lsb_7_0_next;


    wire [11:0] stack_addr;
    reg         ret_addr_en;
    reg         ret_addr_en_next;

    /****************************STATUS_REGISTER BIT MAP*******************************
    *|    7    |    6    |    5    |    4    |    3    |    2    |    1    |    0    |
    *+---------+---------+---------+---------+---------+---------+---------+---------+
    *|  RSVD   |  RSVD   |  RSVD   |  I/TRP  |    Z    |   NZ    | ST-OVF  |   OVF   |
    *+---------+---------+---------+---------+---------+---------+---------+---------+
    */



    reg z_flag;
    reg nz_flag;
    reg ovf_flag;

    reg [3:0] exec_ctrl_1D; //1 cycle delayed version, since register read/imm value takes 1 cycle
    reg       execute_en_1D;
    wire      pc_branch;

    assign pc_branch = ((exec_ctrl[3:0] == `CPU_OPERATION_JMP) || (exec_ctrl[3:0] == `CPU_OPERATION_CALL)) & execute_en;

    assign status_reg = sr_next;

    always @(*) begin
        if(execute_en) begin
            case(exec_ctrl[3:0]) 
                `CPU_OPERATION_JMP : begin
                    if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {CPU_OPERATION_JMP: STATUS_REGISTER = %02x} ",cycle_counter, sr_next);
                end
                `CPU_OPERATION_CALL : begin
                    if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {CPU_OPERATION_CALL: STATUS_REGISTER = %02x} ",cycle_counter, sr_next);
                end
            endcase
        end
    end


    //save return address
    always @(posedge clk) begin
        if(!reset_) begin
            store_ret_addr_upper <= 1'b0;
            store_ret_addr_lower <= 1'b0;
            ret_addr_en <= 1'b0;
        end
        else begin
            store_ret_addr_upper <= latch_ret_addr;
            store_ret_addr_lower <= store_ret_addr_upper;
            ret_addr_en <= ret_addr_en_next;
        end
    end

    always @(posedge clk) begin
        if(latch_ret_addr) begin
            ret_addr1 <= next_addr[11:8];
            ret_addr0 <= next_addr[7:0];
        end
        else if(restore_ret_addr_lower) begin
            ret_addr0 <= d_mem_data_in;
        end
        else if(restore_ret_addr_upper) begin
            ret_addr1 <= d_mem_data_in;
        end
    end

    assign ret_addr = {ret_addr1[3:0],ret_addr0};

    wire sp_incr;
    wire sp_decr;
    assign sp_incr = store_ret_addr_lower || store_ret_addr_upper;
    assign sp_decr = restore_ret_addr_upper || restore_ret_addr_lower;

    always @(posedge clk) begin
        if(!reset_) begin
            sp_lsb_7_0[7:0] <= 8'd0;
        end
        else begin
            sp_lsb_7_0[7:0] <= sp_lsb_7_0_next;
        end
    end

    always @(*) begin
        if(sp_incr) begin
            sp_lsb_7_0_next = sp_lsb_7_0 + 1;
        end
        else if(sp_decr) begin
            sp_lsb_7_0_next = sp_lsb_7_0 - 1;
        end
        else begin
            sp_lsb_7_0_next = sp_lsb_7_0;
        end
    end

    //use 1 cycle delayed version of exec_ctrl, 1 cycle is required for register read/read from memory
    always @(posedge clk) begin
        if(!reset_) begin
            exec_ctrl_1D[3:0] <= `EXEC_NOP;
            sr[7:0]           <= 8'd0;
            execute_en_1D     <= 1'b0;
            reg_wr_sel        <= 2'd0;
        end
        else begin
            exec_ctrl_1D[3:0] <= exec_ctrl;
            execute_en_1D     <= execute_en;
            sr[7:0]           <= sr_next[7:0];
            reg_wr_sel        <= dst_reg;
        end
    end

    //src0 & src1 data (these are available +1 cycle after decode generates the selects)
    assign src0_data = reg_src0_data;
    assign src1_data = imm_data_vld ? imm_data : reg_src1_data; //immediate value will also be available in the next cycle since the immediate value is encoded in the next 8 bit of the original instruction

    //generate memory access control signals
    wire restore_ret_addr_upper;
    wire restore_ret_addr_lower;
    assign restore_ret_addr_lower = ((exec_ctrl[3:0] == `CPU_OPERATION_RET) & execute_en);
    assign restore_ret_addr_upper = ((exec_ctrl_1D[3:0] == `CPU_OPERATION_RET) & execute_en_1D);
    assign d_mem_rd = ((exec_ctrl_1D[3:0] == `MEM_OPERATION_RD) & execute_en_1D) || restore_ret_addr_upper || restore_ret_addr_lower;
    assign d_mem_wr = ((exec_ctrl_1D[3:0] == `MEM_OPERATION_WR) & execute_en_1D) || store_ret_addr_lower || store_ret_addr_upper;
    assign d_mem_en = (d_mem_wr || d_mem_rd) & (execute_en_1D || store_ret_addr_lower || store_ret_addr_upper || restore_ret_addr_upper || restore_ret_addr_lower);

    assign d_mem_data_out[7:0] = (store_ret_addr_lower) ? ret_addr0 : ((store_ret_addr_upper) ? ret_addr1  : src0_data);

    assign stack_addr = (store_ret_addr_lower|store_ret_addr_upper) ? {1'b0, sp_msb_10_8, sp_lsb_7_0} : ({1'b0, sp_msb_10_8, sp_lsb_7_0} - 1);
    assign d_mem_addr = (store_ret_addr_lower|store_ret_addr_upper|restore_ret_addr_upper|restore_ret_addr_lower) ? (stack_addr) : dst_addr;

    //actual operation based on the encoded exec_ctrl info
    always @(*) begin
        reg_wr_data = 8'd0;
        reg_wr_en   = 1'b0;
        z_flag   = 1'b0;
        nz_flag  = 1'b0;
        ovf_flag = 1'b0;
        ret_addr_en_next = 1'b0;
        sr_next = sr;
        if(execute_en_1D) begin
            case(exec_ctrl_1D[3:0])
                `EXEC_NOP : begin
                    if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {EXEC_NOP:} ",cycle_counter);
                end
                `ALU_OPERATION_ADD : begin
                    {ovf_flag, reg_wr_data} = src0_data + src1_data;
                    z_flag = (reg_wr_data == 8'd0);
                    nz_flag = (reg_wr_data != 8'd0);
                    sr_next = {4'd0, z_flag, nz_flag, 1'b0, ovf_flag};
                    reg_wr_en = 1;
                    if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {ALU_OPERATION_ADD: src0_data = %05d, src1_data = %05d, result = %05d: STATUS_REGISTER = %02x} ", cycle_counter, src0_data, src1_data, reg_wr_data, sr_next);
                end
                `ALU_OPERATION_SUB : begin
                    {ovf_flag, reg_wr_data} = src0_data - src1_data;
                    z_flag = (reg_wr_data == 8'd0);
                    nz_flag = (reg_wr_data != 8'd0);
                    sr_next = {4'd0, z_flag, nz_flag, 1'b0, ovf_flag};
                    reg_wr_en = 1;
                    if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {ALU_OPERATION_SUB: src0_data = %05d, src1_data = %05d, result = %05d: STATUS_REGISTER = %02x} ", cycle_counter, src0_data, src1_data, reg_wr_data, sr_next);
                end
                `ALU_OPERATION_OR : begin
                    reg_wr_data = src0_data | src1_data;
                    z_flag = (reg_wr_data == 8'd0);
                    nz_flag = (reg_wr_data != 8'd0);
                    sr_next = {4'd0, z_flag, nz_flag, 2'd0};
                    reg_wr_en = 1;
                    if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {ALU_OPERATION_OR: src0_data = %02x, src1_data = %02x, result = %02x: STATUS_REGISTER = %02x} ", cycle_counter, src0_data, src1_data, reg_wr_data, sr_next);
                end
                `ALU_OPERATION_AND : begin
                    reg_wr_data = src0_data & src1_data;
                    z_flag = (reg_wr_data == 8'd0);
                    nz_flag = (reg_wr_data != 8'd0);
                    sr_next = {4'd0, z_flag, nz_flag, 2'd0};
                    reg_wr_en = 1;
                    if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {ALU_OPERATION_AND: src0_data = %02x, src1_data = %02x, result = %02x: STATUS_REGISTER = %02x} ", cycle_counter, src0_data, src1_data, reg_wr_data, sr_next);
                end
                `ALU_OPERATION_XOR : begin
                    reg_wr_data = src0_data ^ src1_data;
                    z_flag = (reg_wr_data == 8'd0);
                    nz_flag = (reg_wr_data != 8'd0);
                    sr_next = {4'd0, z_flag, nz_flag, 2'd0};
                    reg_wr_en = 1;
                    if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {ALU_OPERATION_XOR: src0_data = %02x, src1_data = %02x, result = %02x: STATUS_REGISTER = %02x} ", cycle_counter, src0_data, src1_data, reg_wr_data, sr_next);
                end
                `MEM_OPERATION_RD : begin
                    reg_wr_data = d_mem_data_in;
                    reg_wr_en = 1;
                    if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {MEM_OPERATION_RD: reg[%d] <= %x: STATUS_REGISTER = %02x} ",cycle_counter, dst_reg, d_mem_data_in, sr_next);
                end
                //`CPU_OPERATION_JMP : begin
                //    sr_next = 8'd0;
                //end
                //`CPU_OPERATION_CALL : begin
                //    sr_next = 8'd0;
                //end
                `MEM_OPERATION_WR : begin
                    if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {MEM_OPERATION_WR: %x => mem[%d] : STATUS_REGISTER = %02x} ",cycle_counter, d_mem_data_out, d_mem_addr, sr_next);
                end
                `CPU_OPERATION_RET : begin
                    sr_next = {4'd0, z_flag, nz_flag, 1'b0, ovf_flag};
                    //sr_next = 8'd0;
                    ret_addr_en_next = 1;
                    if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {CPU_OPERATION_RET: STATUS_REGISTER = %02x} ",cycle_counter, sr_next);
                end
                default : begin
                    sr_next = {4'd0, z_flag, nz_flag, 1'b0, ovf_flag};
                end
            endcase
        end
    end
endmodule
