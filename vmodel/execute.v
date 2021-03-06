/*********************************************************** 
* File Name     : execute.v
* Description   : execute unit
* Organization  : NONE 
* Creation Date : 07-03-2020
* Last Modified : Tuesday 20 April 2021 10:43:32 AM
* Author        : Supratim Das (supratimofficio@gmail.com)
************************************************************/ 
`timescale 1ns/1ps

module execute(
    clk,            //<i
    reset_,         //<i
    cycle_counter,  //<i
    print_en,       //<i //for enabling prints
    latch_ret_addr, //<i //latching return address    
    sp_msb_10_8,    //>i //stack pointer msb 10-8
    reg0,           //<i //register_0 input from register_file 
    reg1,           //<i //register_1 input from register_file
    reg2,           //<i //register_2 input from register_file
    reg3,           //<i //register_3 input from register_file
    cr,             //<i //control_register
    cr_update,      //>o //control_register update value 
    cr_update_en,   //>o //control_register update_en


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

    pc_branch,      //>o    //program_counter branch
    ret_addr,       //>o    //return address
    ret_addr_en,    //>o    //

    status_reg      //>o
);

    //IO ports
    input           clk;
    input           reset_;
    input           print_en;
    input [31:0]    cycle_counter;

    input           execute_en;
    input [7:0]     reg_src0_data;
    input [7:0]     reg_src1_data;
    input [7:0]     imm_data;
    input           imm_data_vld;

    input [1:0]     dst_reg;
    input           latch_ret_addr;

    input [2:0]     sp_msb_10_8;

    output reg [7:0]    reg_wr_data;
    output [1:0]        reg_wr_sel;
    output reg [0:0]    reg_wr_en;
    
    input  [3:0]        exec_ctrl;
    input  [11:0]       dst_addr;
    input  [11:0]       next_addr;
    output [11:0]       d_mem_addr;
    output [7:0]        d_mem_data_out;
    input  [7:0]        d_mem_data_in;

    input  [7:0]        reg0;
    input  [7:0]        reg1;
    input  [7:0]        reg2;
    input  [7:0]        reg3;
    input  [7:0]        cr;

    output              d_mem_en;
    output              d_mem_rd;
    output              d_mem_wr;

    output [7:0]        status_reg;

    output              pc_branch;
    output [11:0]       ret_addr;
    output              ret_addr_en;

    output reg [7:0]    cr_update;
    output reg          cr_update_en;


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


    reg [1:0]    dst_reg_wr_sel;


    wire [11:0] stack_addr;
    reg         ret_addr_en;
    reg         ret_addr_en_next;

    wire [11:0] indirect_addr;

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

`ifndef SYNTHESIS
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
`endif


    //store/restore return address during subroutine call
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

    reg sp_lsb_7_0_update;
    always @(*) begin
        if(sp_incr) begin
            sp_lsb_7_0_next = sp_lsb_7_0 + 1;
        end
        else if(sp_decr) begin
            sp_lsb_7_0_next = sp_lsb_7_0 - 1;
        end
        else if(sp_lsb_7_0_update) begin
            sp_lsb_7_0_next = d_mem_data_out;
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
            dst_reg_wr_sel    <= 2'd0;
        end
        else begin
            exec_ctrl_1D[3:0] <= exec_ctrl;
            execute_en_1D     <= execute_en;
            sr[7:0]           <= sr_next[7:0];
            dst_reg_wr_sel    <= dst_reg;
        end
    end

    reg indirect_reg_wr_access;
    assign reg_wr_sel = indirect_reg_wr_access ? dst_addr[2:0] : dst_reg_wr_sel; 

    //src0 & src1 data (these are available +1 cycle after decode generates the selects)
    assign src0_data = reg_src0_data;
    assign src1_data = imm_data_vld ? imm_data : reg_src1_data; //immediate value will also be available in the next cycle since the immediate value is encoded in the next 8 bit of the original instruction

    //generate memory access control signals
    wire restore_ret_addr_upper;
    wire restore_ret_addr_lower;
    assign restore_ret_addr_lower = ((exec_ctrl[3:0] == `CPU_OPERATION_RET) & execute_en);
    assign restore_ret_addr_upper = ((exec_ctrl_1D[3:0] == `CPU_OPERATION_RET) & execute_en_1D);
    assign d_mem_rd = !memory_mapped_reg_access & (((exec_ctrl_1D[3:0] == `MEM_OPERATION_RD) & execute_en_1D) || restore_ret_addr_upper || restore_ret_addr_lower);
    assign d_mem_wr = !memory_mapped_reg_access & (((exec_ctrl_1D[3:0] == `MEM_OPERATION_WR) & execute_en_1D) || store_ret_addr_lower || store_ret_addr_upper);
    assign d_mem_en = (d_mem_wr || d_mem_rd);

    `ASSERT_NO_X("control signal d_mem_wr cannot be x", u_assert_no_x1, clk, reset_, d_mem_wr)
    `ASSERT_NO_X("control signal d_mem_rd cannot be x", u_assert_no_x2, clk, reset_, d_mem_rd)
    `ASSERT_NO_X("control signal d_mem_en cannot be x", u_assert_no_x3, clk, reset_, d_mem_en)

    assign d_mem_data_out[7:0] = (store_ret_addr_lower) ? ret_addr0 : ((store_ret_addr_upper) ? ret_addr1  : src0_data);

    assign stack_addr = (store_ret_addr_lower|store_ret_addr_upper) ? {1'b0, sp_msb_10_8, sp_lsb_7_0} : ({1'b0, sp_msb_10_8, sp_lsb_7_0} - 1);
    
    reg [11:0] dst_addr_q;
    always @(posedge clk) begin
        if(d_mem_en) begin
            dst_addr_q[11:0] <= dst_addr[11:0];
        end
    end

    wire [11:0] dst_d_mem_addr;
    //assign dst_d_mem_addr[11:0] =(d_mem_wr|d_mem_rd) ? dst_addr : dst_addr_q;
    assign dst_d_mem_addr[11:0] =(d_mem_en) ? dst_addr : dst_addr_q;

    assign indirect_addr = dst_d_mem_addr + reg3;
    assign d_mem_addr = (store_ret_addr_lower|store_ret_addr_upper|restore_ret_addr_upper|restore_ret_addr_lower) ? (stack_addr) : ((cr & `CR_ADR_MODE) ? indirect_addr : dst_d_mem_addr);

    //actual operation based on the encoded exec_ctrl info
    reg memory_mapped_reg_access;
    always @(*) begin
        reg_wr_data = 8'd0;
        reg_wr_en   = 1'b0;
        z_flag   = 1'b0;
        nz_flag  = 1'b0;
        ovf_flag = 1'b0;
        ret_addr_en_next = 1'b0;
        sr_next = sr;
        cr_update = 8'd0;
        cr_update_en = 1'b0;
        sp_lsb_7_0_update = 0;
        indirect_reg_wr_access = 1'b0;
        memory_mapped_reg_access = 1'b0;
        if(execute_en_1D) begin
            case(exec_ctrl_1D[3:0])
                `EXEC_NOP : begin
`ifndef SYNTHESIS
                    if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {EXEC_NOP:} ",cycle_counter);
`endif
                end
                `ALU_OPERATION_ADD : begin
                    {ovf_flag, reg_wr_data} = src0_data + src1_data;
                    z_flag = (reg_wr_data == 8'd0);
                    nz_flag = (reg_wr_data != 8'd0);
                    sr_next = {4'd0, z_flag, nz_flag, 1'b0, ovf_flag};
                    reg_wr_en = 1;
`ifndef SYNTHESIS
                    if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {ALU_OPERATION_ADD: src0_data = %05d, src1_data = %05d, result = %05d: STATUS_REGISTER = %02x} ", cycle_counter, src0_data, src1_data, reg_wr_data, sr_next);
`endif
                end
                `ALU_OPERATION_SUB : begin
                    {ovf_flag, reg_wr_data} = src0_data - src1_data;
                    z_flag = (reg_wr_data == 8'd0);
                    nz_flag = (reg_wr_data != 8'd0);
                    sr_next = {4'd0, z_flag, nz_flag, 1'b0, ovf_flag};
                    reg_wr_en = 1;
`ifndef SYNTHESIS
                    if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {ALU_OPERATION_SUB: src0_data = %05d, src1_data = %05d, result = %05d: STATUS_REGISTER = %02x} ", cycle_counter, src0_data, src1_data, reg_wr_data, sr_next);
`endif
                end
                `ALU_OPERATION_OR : begin
                    reg_wr_data = src0_data | src1_data;
                    z_flag = (reg_wr_data == 8'd0);
                    nz_flag = (reg_wr_data != 8'd0);
                    sr_next = {4'd0, z_flag, nz_flag, 2'd0};
                    reg_wr_en = 1;
`ifndef SYNTHESIS
                    if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {ALU_OPERATION_OR: src0_data = %02x, src1_data = %02x, result = %02x: STATUS_REGISTER = %02x} ", cycle_counter, src0_data, src1_data, reg_wr_data, sr_next);
`endif
                end
                `ALU_OPERATION_AND : begin
                    reg_wr_data = src0_data & src1_data;
                    z_flag = (reg_wr_data == 8'd0);
                    nz_flag = (reg_wr_data != 8'd0);
                    sr_next = {4'd0, z_flag, nz_flag, 2'd0};
                    reg_wr_en = 1;
`ifndef SYNTHESIS
                    if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {ALU_OPERATION_AND: src0_data = %02x, src1_data = %02x, result = %02x: STATUS_REGISTER = %02x} ", cycle_counter, src0_data, src1_data, reg_wr_data, sr_next);
`endif
                end
                `ALU_OPERATION_XOR : begin
                    reg_wr_data = src0_data ^ src1_data;
                    z_flag = (reg_wr_data == 8'd0);
                    nz_flag = (reg_wr_data != 8'd0);
                    sr_next = {4'd0, z_flag, nz_flag, 2'd0};
                    reg_wr_en = 1;
`ifndef SYNTHESIS
                    if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {ALU_OPERATION_XOR: src0_data = %02x, src1_data = %02x, result = %02x: STATUS_REGISTER = %02x} ", cycle_counter, src0_data, src1_data, reg_wr_data, sr_next);
`endif
                end
                `MEM_OPERATION_RD : begin
                    case(dst_addr)
                        12'h000: begin 
                            memory_mapped_reg_access = 1; 
                            reg_wr_data = reg0;
                        end
                        12'h001: begin 
                            memory_mapped_reg_access = 1; 
                            reg_wr_data = reg1;
                        end
                        12'h002: begin 
                            memory_mapped_reg_access = 1; 
                            reg_wr_data = reg2;
                        end
                        12'h003: begin 
                            memory_mapped_reg_access = 1; 
                            reg_wr_data = reg3;
                        end
                        12'h004: begin 
                            memory_mapped_reg_access = 1; 
                            reg_wr_data = cr;
                        end
                        12'h005: begin 
                            memory_mapped_reg_access = 1; 
                            reg_wr_data = sr;
                        end
                        12'h006: begin 
                            memory_mapped_reg_access = 1; 
                            reg_wr_data = sp_lsb_7_0;
                        end
                        12'h007: begin 
                            memory_mapped_reg_access = 1; 
                            reg_wr_data = d_mem_data_in; //TODO: illegal access error
                        end
                        default: begin 
                            memory_mapped_reg_access = 0; 
                            reg_wr_data = d_mem_data_in;
                        end
                    endcase
                    reg_wr_en = 1;
`ifndef SYNTHESIS
                    if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {MEM_OPERATION_RD: reg[%d] <= %x: STATUS_REGISTER = %02x} ",cycle_counter, dst_reg, d_mem_data_in, sr_next);
`endif
                end
                //`CPU_OPERATION_JMP : begin
                //    sr_next = 8'd0;
                //end
                //`CPU_OPERATION_CALL : begin
                //    sr_next = 8'd0;
                //end
                `MEM_OPERATION_WR : begin
                    case(dst_addr)
                        12'h000, 12'h001, 12'h002, 12'h003: begin
                            reg_wr_data = d_mem_data_out; 
                            reg_wr_en = 1; 
                            indirect_reg_wr_access = 1;
                            memory_mapped_reg_access = 1;
                        end
                        12'h004: begin
                            cr_update = d_mem_data_out; 
                            cr_update_en = 1;
                            memory_mapped_reg_access = 1;
                        end
                        12'h005: begin
                            sr_next = sr;
                            memory_mapped_reg_access = 1;
                        end
                        12'h006: begin 
                            sp_lsb_7_0_update = 1;
                            memory_mapped_reg_access = 1;
                        end
                    endcase

`ifndef SYNTHESIS
                    if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {MEM_OPERATION_WR: %x => mem[%d] : STATUS_REGISTER = %02x} ",cycle_counter, d_mem_data_out, d_mem_addr, sr_next);
`endif
                end
                `CPU_OPERATION_RET : begin
                    sr_next = {4'd0, z_flag, nz_flag, 1'b0, ovf_flag};
                    //sr_next = 8'd0;
                    ret_addr_en_next = 1;
`ifndef SYNTHESIS
                    if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {CPU_OPERATION_RET: STATUS_REGISTER = %02x} ",cycle_counter, sr_next);
`endif
                end
                default : begin
                    sr_next = {4'd0, z_flag, nz_flag, 1'b0, ovf_flag};
                end
            endcase
        end
    end
endmodule
