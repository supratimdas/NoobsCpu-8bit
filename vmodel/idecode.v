/*********************************************************** 
* File Name     : idecode.v
* Description   :
* Organization  : NONE 
* Creation Date : 11-05-2019
* Last Modified : Monday 01 February 2021 07:55:26 PM IST
* Author        : Supratim Das (supratimofficio@gmail.com)
************************************************************/ 
`timescale 1ns/1ps

`include "noobs_cpu_defines.vh"

module idecode (
    clk,                        //<i
    cycle_counter,              //<i
    print_en,                   //<i
    reset_,                     //<i
    idecode_en,                 //<i
    inst_i,                     //<i    //input from ifetch stage
    tgt_addr,                   //<i 

    exec_ctrl,                  //>o    //encoded execute control to execute unit
    exec_src0_reg,              //>o    //register file rd_sel_0
    exec_src0_reg_rd_en,        //>o    //rd_en_0
    exec_src1_reg,              //>o    //register file rd_sel_1
    exec_src1_reg_rd_en,        //>o    //rd_en_1
    exec_dst_reg,               //>o    //register file wr_reg_sel
    exec_addr,                  //>o    //data memory access addr
    exec_imm_val,               //>o    //immediate value
    exec_imm_val_vld,           //>o    //immediate value valid
    decode2ifetch_en,           //>o    //instruction fetch_en
    decode2exec_en,             //>o    //instruction execute_en
    decode2exec_latch_ret_addr, //>o    //output to immediately latch the return address in temporary flop
    sr,                         //<i    //status register
    sp_msb_10_8,                //>o    //stack pointer msb 10-8
);
    //IOs
    input            clk;
    input            reset_;
    input            print_en;
    input [31:0]     cycle_counter;

    input            idecode_en;
    input [7:0]      inst_i;

    output reg [3:0]    exec_ctrl;
    output reg [1:0]    exec_src0_reg;
    output reg [0:0]    exec_src0_reg_rd_en;
    output reg [1:0]    exec_src1_reg;
    output reg [0:0]    exec_src1_reg_rd_en;
    output reg [7:0]    exec_imm_val;
    output reg [0:0]    exec_imm_val_vld;
    output reg [1:0]    exec_dst_reg;
    output reg [11:0]   exec_addr;


    output decode2ifetch_en;
    output decode2exec_en;
    output decode2exec_latch_ret_addr;

    input [7:0]         sr;
    output [11:0]       tgt_addr;
    output [2:0]        sp_msb_10_8; //upper 3 bit for stack pointer from control register

 /****************************STATUS_REGISTER BIT MAP******************************
 *|    7    |    6    |    5    |    4    |    3    |    2    |    1    |    0    |
 *+---------+---------+---------+---------+---------+---------+---------+---------+
 *|  RSVD   |  RSVD   |  RSVD   |  I/TRP  |    Z    |   NZ    | ST-OVF  |   OVF   |
 *+---------+---------+---------+---------+---------+---------+---------+---------+
 */

    assign tgt_addr = exec_addr_next;

    //regs
    reg [0:0] imm_mode;
    reg [7:0] prev_inst;
    reg [0:0] imm_mode_next;
    reg [0:0] fetch_en_next;

    reg [0:0] exec_en;
    reg [0:0] fetch_en;

    reg [1:0]  exec_src0_reg_next;
    reg        exec_src0_reg_rd_en_next;
    reg [1:0]  exec_src1_reg_next;
    reg        exec_src1_reg_rd_en_next;
    reg [1:0]  exec_dst_reg_next;
    reg [7:0]  exec_imm_val_next;
    reg        exec_imm_val_vld_next;

    reg [11:0] exec_addr_next;
    reg [3:0]  exec_ctrl_next;

    reg [0:0] exec_en_next;

    reg [0:0] fatal_err;
    reg [0:0] unimplemented_err;

    reg [0:0] halted_next;
    reg [0:0] halted;

    reg [0:0] soft_rst_next;
    reg [0:0] soft_rst;

    reg [7:0] cr; //TODO: should also be accesible in mem_addr: 0x04 (need to implement)
    reg [7:0] cr_next;
    /****************************CONTROL_REGISTER BIT MAP*****************************
    *|    7    |    6    |    5    |    4    |    3    |    2    |    1    |    0    |
    *+---------+---------+---------+---------+---------+---------+---------+---------+
    *|  RSVD   |  RSVD   |  RSVD   | SP_MSB10| SP_MSB9 | SP_MSB8 |  BCNZ   |   BCZ   |
    *+---------+---------+---------+---------+---------+---------+---------+---------+
    */       

    //wires
    wire [7:0] curr_inst;

    assign curr_inst = func_ret ? `OP_CODE_NOP : inst_i;

    assign sp_msb_10_8[2:0] = cr[4:3]; //as per control register map


    assign decode2ifetch_en = fetch_en & ~halted & ~ret_op_restore_ongoing;
    assign decode2exec_en = exec_en & ~halted;
    assign decode2exec_latch_ret_addr = (exec_ctrl_next == `CPU_OPERATION_CALL);


    wire func_ret_next;
    assign func_ret_next = idecode_en & (exec_ctrl_next == `CPU_OPERATION_RET);

    reg func_ret;
    reg func_ret_q;

    always @(posedge clk) begin
        if(!reset_) begin
            func_ret    <= 1'b0;
            func_ret_q  <= 1'b0;
        end
        else begin
            func_ret    <= func_ret_next;
            func_ret_q  <= func_ret;
        end
    end

    wire ret_op_restore_ongoing;
    assign ret_op_restore_ongoing = func_ret || func_ret_q;

    //retimer
    always @(posedge clk) begin
        if(!reset_) begin 
            imm_mode            <= 1'b0;
            prev_inst           <= 8'h00;
            exec_ctrl           <= `EXEC_NOP;
            fetch_en            <= 1'b1;
            exec_addr           <= 12'd0;
            exec_src0_reg       <= 2'd0;
            exec_src0_reg_rd_en <= 1'b0;
            exec_src1_reg       <= 2'd0;
            exec_src1_reg_rd_en <= 1'b0;
            exec_dst_reg        <= 2'd0; 
            exec_imm_val        <= 8'd0;
            exec_imm_val_vld    <= 1'b0;
            exec_en             <= 1'b0;
            halted              <= 1'b0;
            soft_rst            <= 1'b0;
            cr                  <= `CR_SP_INIT_MSB;
        end
        //else if(idecode_en) begin
        else begin
            imm_mode            <= imm_mode_next;
            prev_inst           <= curr_inst;
            exec_ctrl           <= exec_ctrl_next;
            exec_addr           <= exec_addr_next;
            fetch_en            <= fetch_en_next;
            exec_src0_reg       <= exec_src0_reg_next;
            exec_src0_reg_rd_en <= exec_src0_reg_rd_en_next;
            exec_src1_reg       <= exec_src1_reg_next;
            exec_src1_reg_rd_en <= exec_src1_reg_rd_en_next;
            exec_dst_reg        <= exec_dst_reg_next;
            exec_imm_val        <= exec_imm_val_next;
            exec_imm_val_vld    <= exec_imm_val_vld_next;
            exec_en             <= exec_en_next;
            halted              <= halted_next|halted; //sticky
            soft_rst            <= soft_rst_next;
            cr                  <= cr_next;
        end
    end


    always @(*) begin
        //initialize all variables to 0 to avoid latch
        imm_mode_next = imm_mode;
        fetch_en_next = fetch_en;
        exec_addr_next = exec_addr;
        exec_src0_reg_next = exec_src0_reg;
        exec_src0_reg_rd_en_next = 1'b0;
        exec_src1_reg_next = exec_src1_reg;
        exec_src1_reg_rd_en_next = 1'b0;
        exec_dst_reg_next = exec_dst_reg;
        exec_ctrl_next = exec_ctrl;
        exec_imm_val_next = exec_imm_val;
        exec_imm_val_vld_next = exec_imm_val_vld;
        halted_next = 1'b0;
        soft_rst_next = 1'b0;

        fatal_err = 1'b0;
        unimplemented_err = 1'b0;

        cr_next = cr;
        
        if(idecode_en) begin // {
            if(imm_mode) begin // {
                exec_imm_val_vld_next = 1'b1;
                imm_mode_next = 1'b0;
                exec_en_next = 1'b0;
                exec_ctrl_next = `EXEC_NOP;
                casez(`GET_BASE_OP(prev_inst))
                    `MC_CTRL_USR : begin
                        casez(`GET_MC_CTRL_USR_OP(prev_inst)) 
                            `JMP: begin
                                exec_addr_next = ((prev_inst & 8'h07) << 8) | curr_inst;
                                fetch_en_next = 1'b1;
                                if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE_JMP: ADDRESS = %d} ",cycle_counter, exec_addr_next);
                            end
                            `CALL: begin 
                                exec_addr_next = ((prev_inst & 8'h07) << 8) | curr_inst;
                                fetch_en_next = 1'b1;
                                if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE_CALL: ADDRESS = %d} ",cycle_counter, exec_addr_next);
                            end
                            default: begin
                                if(`DEBUG_PRINT & print_en) $display("cycle = %05d: OPCODE: %02x", cycle_counter,prev_inst);
                                fatal_err = 1'b1;
                            end
                        endcase
                        exec_imm_val_next = curr_inst;
                    end
                    `ADD: begin
                        exec_imm_val_next = curr_inst;
                        if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE_ADD: IMMEDIATE_VAL = %d} ", cycle_counter,exec_imm_val_next);
                    end
                    `SUB: begin
                        exec_imm_val_next = curr_inst;
                        if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE_SUB: IMMEDIATE_VAL = %d} ", cycle_counter,exec_imm_val_next);
                    end
                    `AND: begin
                        exec_imm_val_next = curr_inst;
                        if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE_AND: IMMEDIATE_VAL = %d} ", cycle_counter,exec_imm_val_next);
                    end
                    `OR: begin 
                        exec_imm_val_next = curr_inst;
                        if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE_OR: IMMEDIATE_VAL = %d} ", cycle_counter,exec_imm_val_next);
                    end
                    `XOR: begin 
                        exec_imm_val_next = curr_inst;
                        if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE_XOR: IMMEDIATE_VAL = %d} ", cycle_counter,exec_imm_val_next);
                    end
                    `LD: begin
                        exec_addr_next = ((prev_inst & 8'h07) << 8) | curr_inst;
                        if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE_LD: ADDRESS = %d} ",cycle_counter, exec_addr_next);
                    end
                    `ST: begin
                        exec_addr_next = ((prev_inst & 8'h07) << 8) | curr_inst;
                        if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE_ST: ADDRESS = %d} ",cycle_counter, exec_addr_next);
                    end
                    default: begin
                        if(`DEBUG_PRINT & print_en) $display("cycle = %05d: OPCODE: %02x\n",cycle_counter, prev_inst);
                        fatal_err = 1'b1;
                    end
                endcase
            end //} imm_mode
            else begin //{ !imm_mode
                imm_mode_next = `IS_IMM(curr_inst);
                exec_imm_val_vld_next = 1'b0;
                casez(`GET_BASE_OP(curr_inst))
                    `MC_CTRL_USR: begin
                        casez(`GET_MC_CTRL_USR_OP(curr_inst))
                            `MISC: begin
                                casez(curr_inst & 8'h07)
                                    `NOP: begin
                                       if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE: NOP}", cycle_counter);
                                       exec_ctrl_next = `EXEC_NOP; 
                                    end
                                    `RET: begin
                                       if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE: RET}", cycle_counter);
                                       exec_ctrl_next = `CPU_OPERATION_RET; 
                                       fetch_en_next = 1'b1;
                                    end
                                    `HALT: begin
                                       if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE: HALT}", cycle_counter);
                                       fetch_en_next = 1'b0;
                                       halted_next = 1'b1;
                                    end
                                    `RST: begin
                                       if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE: RESET}", cycle_counter);
                                       soft_rst_next = 1'b1;
                                    end
                                    `SET_BCZ: begin
                                       if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE: SET_BCZ}", cycle_counter);
                                       exec_ctrl_next = `EXEC_NOP;
                                       cr_next = (cr_next & (~`CR_BCNZ)) | `CR_BCZ;
                                    end
                                    `SET_BCNZ: begin
                                       if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE: SET_BCNZ}", cycle_counter);
                                       exec_ctrl_next = `EXEC_NOP;
                                       cr_next = (cr_next & (~`CR_BCZ)) | `CR_BCNZ;
                                    end
                                    `CLR_BC: begin
                                       if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE: CLR_BC}", cycle_counter);
                                       exec_ctrl_next = `EXEC_NOP;
                                       cr_next = (cr_next & (~(`CR_BCZ | `CR_BCNZ)));
                                    end
                                    default: begin
                                       if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE: UNKNOWN}", cycle_counter);
                                       fatal_err = 1'b1;
                                    end
                                endcase
                             end
                            `USR: begin
                                //TODO: unimplimented feature
                                exec_ctrl_next = `NOP;
                                unimplemented_err = 1'b1;
                            end
                            `JMP: begin
                                if(~(cr[`CR_BCNZ_BIT_POS] | cr[`CR_BCZ_BIT_POS]) || //unconditional branch
                                    (cr[`CR_BCNZ_BIT_POS] & sr[`SR_NZ_BIT_POS]) || //branch if zero condition true
                                    (cr[`CR_BCZ_BIT_POS] & sr[`SR_Z_BIT_POS])) begin //branch if zero condition true
                                    exec_ctrl_next = `CPU_OPERATION_JMP;
                                    if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE: JMP_TRUE}", cycle_counter);
                                end
                                else begin
                                    exec_ctrl_next = `EXEC_NOP;
                                    if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE: JMP_FALSE}", cycle_counter);
                                end
                            end
                            `CALL: begin
                                //if( ~(cr[`CR_BCNZ_BIT_POS] | cr[`CR_BCZ_BIT_POS]) || //unconditional branch
                                //     (cr[`CR_BCNZ_BIT_POS] & sr[`SR_NZ_BIT_POS]) || //branch if zero condition true
                                //     (cr[`CR_BCZ_BIT_POS] & sr[`SR_Z_BIT_POS])) begin //branch if zero condition true
                                //    exec_ctrl_next = `CPU_OPERATION_CALL;
                                //    if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE: CALL_TRUE}", cycle_counter);
                                //end
                                //else begin
                                //    exec_ctrl_next = `EXEC_NOP;
                                //    if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE: CALL_FALSE}", cycle_counter);
                                //end
                                exec_ctrl_next = `CPU_OPERATION_CALL;
                                if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE: CALL_TRUE}", cycle_counter);
                            end
                            default: begin
                                       if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE: UNKNOWN}", cycle_counter);
                                       fatal_err = 1'b1;
                            end
                        endcase
                    end
                    `ADD: begin
                        exec_ctrl_next = `ALU_OPERATION_ADD;
                        if(imm_mode_next) begin
                            exec_src0_reg_next = `GET_REG_PTR0(curr_inst);
                            exec_src0_reg_rd_en_next = 1'b1;
                            exec_dst_reg_next = `GET_REG_PTR1(curr_inst);
                            if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE: ADDI: src0_reg = %d, dst_reg = %d} ", cycle_counter,exec_src0_reg_next, exec_dst_reg_next);
                        end
                        else begin
                            exec_src0_reg_next = `GET_REG_PTR0(curr_inst);
                            exec_src0_reg_rd_en_next = 1'b1;
                            exec_src1_reg_next = `GET_REG_PTR1(curr_inst);
                            exec_src1_reg_rd_en_next = 1'b1;
                            exec_dst_reg_next = `GET_REG_PTR1(curr_inst);
                            if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE: ADD: src0_reg = %d, src1_reg = %d, dst_reg = %d} ",cycle_counter, exec_src0_reg_next, exec_src1_reg_next, exec_dst_reg_next);
                        end
                    end
                    `SUB: begin
                        exec_ctrl_next = `ALU_OPERATION_SUB;
                        if(imm_mode_next) begin
                            exec_src0_reg_next = `GET_REG_PTR0(curr_inst);
                            exec_src0_reg_rd_en_next = 1'b1;
                            exec_dst_reg_next = `GET_REG_PTR1(curr_inst);
                            if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE: SUBI: src0_reg = %d, dst_reg = %d} ", cycle_counter,exec_src0_reg_next, exec_dst_reg_next);
                        end
                        else begin
                            exec_src0_reg_next = `GET_REG_PTR0(curr_inst);
                            exec_src0_reg_rd_en_next = 1'b1;
                            exec_src1_reg_next = `GET_REG_PTR1(curr_inst);
                            exec_src1_reg_rd_en_next = 1'b1;
                            exec_dst_reg_next = `GET_REG_PTR1(curr_inst);
                            if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE: SUB: src0_reg = %d, src1_reg = %d, dst_reg = %d} ",cycle_counter, exec_src0_reg_next, exec_src1_reg_next, exec_dst_reg_next);
                        end
                    end
                    `AND: begin
                        exec_ctrl_next = `ALU_OPERATION_AND;
                        if(imm_mode_next) begin
                            exec_src0_reg_next = `GET_REG_PTR0(curr_inst);
                            exec_src0_reg_rd_en_next = 1'b1;
                            exec_dst_reg_next = `GET_REG_PTR1(curr_inst);
                            if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE: ANDI: src0_reg = %d, dst_reg = %d} ", cycle_counter,exec_src0_reg_next, exec_dst_reg_next);
                        end
                        else begin
                            exec_src0_reg_next = `GET_REG_PTR0(curr_inst);
                            exec_src0_reg_rd_en_next = 1'b1;
                            exec_src1_reg_next = `GET_REG_PTR1(curr_inst);
                            exec_src1_reg_rd_en_next = 1'b1;
                            exec_dst_reg_next = `GET_REG_PTR1(curr_inst);
                            if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE: AND: src0_reg = %d, src1_reg = %d, dst_reg = %d} ",cycle_counter, exec_src0_reg_next, exec_src1_reg_next, exec_dst_reg_next);
                        end
                    end
                    `OR: begin
                        exec_ctrl_next = `ALU_OPERATION_OR;
                        if(imm_mode_next) begin
                            exec_src0_reg_next = `GET_REG_PTR0(curr_inst);
                            exec_src0_reg_rd_en_next = 1'b1;
                            exec_dst_reg_next = `GET_REG_PTR1(curr_inst);
                            if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE: ORI: src0_reg = %d, dst_reg = %d} ", cycle_counter,exec_src0_reg_next, exec_dst_reg_next);
                        end
                        else begin
                            exec_src0_reg_next = `GET_REG_PTR0(curr_inst);
                            exec_src0_reg_rd_en_next = 1'b1;
                            exec_src1_reg_next = `GET_REG_PTR1(curr_inst);
                            exec_src1_reg_rd_en_next = 1'b1;
                            exec_dst_reg_next = `GET_REG_PTR1(curr_inst);
                            if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE: OR: src0_reg = %d, src1_reg = %d, dst_reg = %d} ",cycle_counter, exec_src0_reg_next, exec_src1_reg_next, exec_dst_reg_next);
                        end
                    end
                    `XOR: begin
                        exec_ctrl_next = `ALU_OPERATION_XOR;
                        if(imm_mode_next) begin
                            exec_src0_reg_next = `GET_REG_PTR0(curr_inst);
                            exec_src0_reg_rd_en_next = 1'b1;
                            exec_dst_reg_next = `GET_REG_PTR1(curr_inst);
                            if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE: XORI: src0_reg = %d, dst_reg = %d} ", cycle_counter,exec_src0_reg_next, exec_dst_reg_next);
                        end
                        else begin
                            exec_src0_reg_next = `GET_REG_PTR0(curr_inst);
                            exec_src0_reg_rd_en_next = 1'b1;
                            exec_src1_reg_next = `GET_REG_PTR1(curr_inst);
                            exec_src1_reg_rd_en_next = 1'b1;
                            exec_dst_reg_next = `GET_REG_PTR1(curr_inst);
                            if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE: XOR: src0_reg = %d, src1_reg = %d, dst_reg = %d} ",cycle_counter, exec_src0_reg_next, exec_src1_reg_next, exec_dst_reg_next);
                        end
                    end
                    `LD: begin
                        exec_ctrl_next = `MEM_OPERATION_RD;
                        exec_dst_reg_next = `GET_LD_ST_REG_PTR(curr_inst);
                        imm_mode_next = 1'b1;
                        if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE: LOAD reg[%d]} ", cycle_counter,exec_dst_reg_next);
                    end
                    `ST: begin
                        exec_ctrl_next = `MEM_OPERATION_WR;
                        exec_src0_reg_next = `GET_LD_ST_REG_PTR(curr_inst);
                        exec_src0_reg_rd_en_next = 1'b1;
                        imm_mode_next = 1'b1;
                        if(`DEBUG_PRINT & print_en) $display("cycle = %05d: {IDECODE: STORE reg[%d]} ", cycle_counter,exec_dst_reg_next);
                    end
                endcase
                
                exec_en_next = 1;
            end // } !imm_mode
        end // } idecode_en
        else begin // { !idecode_en
            exec_en_next = 1'b0;
        end // }
    end


    //assertions
    assert_never #("Unimplemeneted or Illegal Instruction error") u_assert_never_1 (clk,unimplemented_err); 
    assert_never #("Fatal error") u_assert_never_2 (clk,fatal_err); 
endmodule
