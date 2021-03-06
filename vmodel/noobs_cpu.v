/*********************************************************** 
* File Name     : noobs_cpu.v
* Description   : toplevel file
* Organization  : NONE 
* Creation Date : 05-03-2020
* Last Modified : Friday 09 April 2021 08:57:14 PM
* Author        : Supratim Das (supratimofficio@gmail.com)
************************************************************/ 
`timescale 1ns/1ps

//Short Summary:
//This is the toplevel file that instances
//fetch_unit
//decode_unit
//control_unit
//register_file
//it has interfaces for instruction memory and data memory

module noobs_cpu (
    clk,            //<i
    reset_,         //<i
`ifdef SYNTHESIS_DEBUG
    REG0,   //> o
    REG1,   //> o
    REG2,   //> o
    REG3,   //> o
    REG_WR_DATA, // > o
    REG_WR_SEL, // > o
    REG_WR_EN,  // > o
`endif
    i_data,         //<i inst_mem_data
    i_addr,         //>o inst_mem_address

    m_wr_data,      //>o  data_mem_data wr_data
    m_rd_data,      //<i  data_mem_data rd_data
    m_addr,         //>o  data_mem_addr
    m_rd,           //>o  data_mem_rd enable
    m_wr,           //>o  data_mem_wr enable
    m_en            //>   data_mem en
);

    //IOs
    input           clk;
    input           reset_;

    input [7:0]     i_data;
    output [11:0]   i_addr;

    input [7:0]     m_rd_data;
    output [7:0]    m_wr_data;
    output [11:0]   m_addr;

    output          m_rd;
    output          m_wr;
    output          m_en;
`ifdef SYNTHESIS_DEBUG
    output [7:0] REG0;   //> o
    output [7:0] REG1;   //> o
    output [7:0] REG2;   //> o
    output [7:0] REG3;   //> o
    output [7:0] REG_WR_DATA;   //> o
    output [1:0] REG_WR_SEL;   //> o
    output REG_WR_EN;   //> o

    assign REG0 = reg0;
    assign REG1 = reg1;
    assign REG2 = reg2;
    assign REG3 = reg3;
    assign REG_WR_DATA = wr_data;
    assign REG_WR_SEL = wr_sel; 
    assign REG_WR_EN = wr_en;
`endif

    //wires
    wire            pc_branch;
    wire [11:0]     tgt_addr;
    wire [7:0]      inst_o;

    wire            ifetch_en;
    wire            execute_en;
    wire [3:0]      exec_ctrl;

    wire [1:0]      rd_sel_0;
    wire [1:0]      rd_sel_1;

    wire [7:0]      rd_data_0;
    wire [7:0]      rd_data_1;

    wire            rd_en_0;
    wire            rd_en_1;

    wire [1:0]      dst_reg;

    wire [1:0]      wr_sel;
    wire [7:0]      wr_data;
    wire            wr_en;

    wire [7:0]      imm_data;
    wire            imm_data_vld;
    wire [11:0]     dst_addr;

    wire [7:0]      sr; //status register

    wire            idecode_en;

    wire [11:0]     next_addr;

    wire            latch_ret_addr;

    wire [2:0]      sp_msb_10_8; //upper bits of programmable stack pointer
    wire [11:0]     ret_addr;
    wire            ret_addr_en;

    wire [7:0]      reg0;
    wire [7:0]      reg1;
    wire [7:0]      reg2;
    wire [7:0]      reg3;

    wire [7:0]      cr;
    wire [7:0]      cr_update;
    wire            cr_update_en;

`ifdef SYNTHESIS
   wire [31:0] cycle_counter;
   wire print_en;
   assign cycle_counter[31:0] = 32'd0;
   assign print_en = 0;
`else
    reg [31:0]      cycle_counter; //for debug
    always @(posedge clk) begin
        if(!reset_) begin
           cycle_counter <= 32'd0; 
        end
        else begin
           cycle_counter <= cycle_counter + 1'b1;
        end
    end

    reg print_en;
    always @(posedge clk or negedge clk) begin
        if(!reset_) begin
            print_en <= 0;
        end

        if(clk == 1) print_en <= 0;
        if(clk == 0) print_en <= 1;
    end
`endif


    //submodule instances
    //instance from ifetch.v
    ifetch u_ifetch(
        .clk(clk),              //< i
        .reset_(reset_),        //< i
        .branch(pc_branch),     //< i 
        .ifetch_en(ifetch_en),  //< i
        .inst_i(i_data),        //< i
        .tgt_addr(tgt_addr),    //< i
        .ret_addr(ret_addr),    //< i    //return address
        .ret_addr_en(ret_addr_en),    //< i    //return address
        .inst_o(inst_o),        //> o
        .idecode_en(idecode_en),//>o
        .inst_addr(i_addr),     //> o
        .next_addr(next_addr)   //>o
    );


    //instance from idecode.v
    idecode u_idecode(
        .clk(clk),                                          //<i
        .cycle_counter(cycle_counter),                      //<i
        .print_en(print_en),                                //<i
        .reset_(reset_),                                    //<i
        .idecode_en(idecode_en),                            //<i
        .inst_i(inst_o),                                    //<i
        .tgt_addr(tgt_addr),                                //>o
        .exec_ctrl(exec_ctrl),                              //>o
        .exec_src0_reg(rd_sel_0),                           //>o
        .exec_src0_reg_rd_en(rd_en_0),                      //>o
        .exec_src1_reg(rd_sel_1),                           //>o
        .exec_src1_reg_rd_en(rd_en_1),                      //>o
        .exec_dst_reg(dst_reg),                             //>o
        .exec_addr(dst_addr),                               //>o
        .exec_imm_val(imm_data),                            //>o
        .exec_imm_val_vld(imm_data_vld),                    //>o
        .decode2ifetch_en(ifetch_en),                       //>o
        .decode2exec_en(execute_en),                        //>o
        .decode2exec_latch_ret_addr(latch_ret_addr),        //>o    //output to immediately latch the return address in temporary flop
        .sp_msb_10_8(sp_msb_10_8),                          //<o
        .sr(sr),                                            //<i
        .cr(cr),                                            //>o
        .cr_update(cr_update),                              //<i
        .cr_update_en(cr_update_en)                         //<i

    );


    //instance from register_file.v
    reg_file u_reg_file(
        .clk(clk),              //<i
        .reset_(reset_),        //<i
        .reg0(reg0),            //>o
        .reg1(reg1),            //>o
        .reg2(reg2),            //>o
        .reg3(reg3),            //>o
        .rd_sel_0(rd_sel_0),    //<i
        .rd_en_0(rd_en_0),      //<i
        .rd_sel_1(rd_sel_1),    //<i
        .rd_en_1(rd_en_1),      //<i
        .wr_sel(wr_sel),        //<i
        .wr_en(wr_en),          //<i
        .wr_data(wr_data),      //<i
        .rd_data_0(rd_data_0),  //>o
        .rd_data_1(rd_data_1)   //>0
    );

    //instance from execute.v
    execute u_execute(
        .clk(clk),                  //<i
        .cycle_counter(cycle_counter), //<i
        .print_en(print_en),        //<i
        .reset_(reset_),            //<i
        .execute_en(execute_en),    //<i
        .latch_ret_addr(latch_ret_addr), //<i
        .reg_src0_data(rd_data_0),  //<i 
        .reg_src1_data(rd_data_1),  //<i 
        .imm_data(imm_data),        //<i
        .imm_data_vld(imm_data_vld),//<i
        .dst_reg(dst_reg),          //<i
        .reg_wr_data(wr_data),      //>o
        .reg_wr_sel(wr_sel),        //>o
        .reg_wr_en(wr_en),          //>o
        .exec_ctrl(exec_ctrl),      //<i
        .dst_addr(dst_addr),        //<i
        .d_mem_addr(m_addr),        //>o
        .d_mem_data_in(m_rd_data),  //<i
        .d_mem_data_out(m_wr_data), //>o
        .d_mem_en(m_en),            //>o
        .d_mem_rd(m_rd),            //>o
        .d_mem_wr(m_wr),            //>o
        .pc_branch(pc_branch),      //>o
        .status_reg(sr),            //>o
        .sp_msb_10_8(sp_msb_10_8),  //<i
        .ret_addr(ret_addr),        //>o    //return address
        .ret_addr_en(ret_addr_en),  //>o    //return address
        .next_addr(next_addr),      //<i
        .reg0(reg0),                //<i
        .reg1(reg1),                //<i
        .reg2(reg2),                //<i
        .reg3(reg3),                //<i
        .cr(cr),                    //<i
        .cr_update(cr_update),      //>o
        .cr_update_en(cr_update_en) //>o
    );

    wire data_memory_access_error;
    assign data_memory_access_error = m_en & m_wr & m_rd;
    `ASSERT_NEVER("data_mem rd and wr can never be set simultaneosly", u_assert_never_1, clk, reset_, data_memory_access_error)
endmodule
