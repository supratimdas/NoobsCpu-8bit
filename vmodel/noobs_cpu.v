/*********************************************************** 
* File Name     : noobs_cpu.v
* Description   : toplevel file
* Organization  : NONE 
* Creation Date : 05-03-2020
* Last Modified : Tuesday 23 June 2020 03:06:28 PM IST
* Author        : Supratim Das (supratimofficio@gmail.com)
************************************************************/ 

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
    
    i_data,         //<i inst_mem_data
    i_addr,         //>o inst_mem_address

    m_data,         //<io>  data_mem_data
    m_addr,         //>o    data_mem_addr
    m_rd,           //>o    data_mem_rd enable
    m_wr,           //>o    data_mem_wr enable
    m_en            //>     data_mem en
);

    //IOs
    input           clk;
    input           reset_;

    input [7:0]     i_data;
    output [11:0]   i_addr;

    inout [7:0]     m_data;
    output [11:0]   m_addr;

    output          m_rd;
    output          m_wr;
    output          m_en;

    //wires
    wire            branch;
    wire            ifetch_en;
    wire [11:0]     tgt_addr;
    wire [11:0]     next_addr;
    wire [7:0]      inst_o;

    wire            idecode_en;
    wire [3:0]      decode2cpu_ctrl_cmd;
    wire [3:0]      exec_ctrl;

    wire [2:0]      cbr_status;

    wire [2:0]      rd_sel_0;
    wire [2:0]      rd_sel_1;

    wire [7:0]      rd_data_0;
    wire [7:0]      rd_data_1;

    wire            rd_en_0;
    wire            rd_en_1;

    wire [2:0]      dst_reg;

    wire [2:0]      wr_sel;
    wire [7:0]      wr_data;
    wire            wr_en;

    wire [7:0]      imm_data;
    wire            imm_data_vld;
    wire [11:0]     dst_addr;

    wire            execute_en;


    assign branch = cbr_status[1];

    //submodule instances
    ifetch u_ifetch(
        .clk(clk),              //< i
        .reset_(reset_),        //< i
        .branch(branch),        //< i
        .ifetch_en(ifetch_en),  //< i
        .inst_i(i_data),        //< i
        .tgt_addr(tgt_addr),    //< i
        .inst_o(inst_o),        //> o
        .next_addr(next_addr),  //> o
        .inst_addr(i_addr)      //> o
    );


    idecode u_idecode(
        .clk(clk),                                          //<i
        .reset_(reset_),                                    //<i
        .idecode_en(idecode_en),                            //<i
        .inst_i(inst_o),                                    //<i
        .exec_ctrl(exec_ctrl),                              //>o
        .exec_src0_reg(rd_sel_0),                           //>o
        .exec_src0_reg_rd_en(rd_en_0),                      //>o
        .exec_src1_reg(rd_sel_1),                           //>o
        .exec_src1_reg_rd_en(rd_en_1),                      //>o
        .exec_dst_reg(dst_reg),                             //>o
        .exec_addr(dst_addr),                               //>o
        .exec_imm_val(imm_data),                            //>o
        .exec_imm_val_vld(imm_data_vld),                    //>o
        .decode2cpu_ctrl_cmd(decode2cpu_ctrl_cmd)           //>o
    );


    cpu_control u_cpu_control(
        .clk(clk),                                      //<i
        .reset_(reset_),                                //<i
        .decode2cpu_ctrl_cmd(decode2cpu_ctrl_cmd),      //<i
        .cbr_status(cbr_status),                        //<i    call, branch, return
        .ifetch_en(ifetch_en),                          //>o
        .execute_en(execute_en),                        //>o
        .idecode_en(idecode_en),                        //>o
        .pc_reset(),                                    //>o
        .pc_branch()                                    //>o
    );


    reg_file u_reg_file(
        .clk(clk),              //<i
        //reset_,     //<i
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

    execute u_execute(
        .clk(clk),                  //<i
        .reset_(reset_),            //<i
        .tgt_addr(tgt_addr),        //>o
        .next_addr(next_addr),      //<i
        .execute_en(execute_en),    //<i
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
        .d_mem_data_in(m_data),     //<io>
        .d_mem_data_out(m_data),    //<io>
        .d_mem_en(m_en),            //>o
        .d_mem_rd(m_rd),            //>o
        .d_mem_wr(m_wr)             //>o
    );


endmodule
