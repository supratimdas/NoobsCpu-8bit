/*********************************************************** 
* File Name     : idecode.v
* Description   :
* Organization  : NONE 
* Creation Date : 11-05-2019
* Last Modified : Friday 15 January 2021 10:07:29 PM IST
* Author        : Supratim Das (supratimofficio@gmail.com)
************************************************************/ 
`timescale 1ns/1ps

`include "noobs_cpu_defines.vh"

module idecode (
    clk,                //<i
    reset_,             //<i
    idecode_en,         //<i
    inst_i,             //<i    //input from ifetch stage
    
    exec_ctrl,          //>o    //encoded execute control to execute unit
    exec_src0_reg,      //>o    //register file rd_sel_0
    exec_src0_reg_rd_en,//>o    //rd_en_0
    exec_src1_reg,      //>o    //register file rd_sel_1
    exec_src1_reg_rd_en,//>o    //rd_en_1
    exec_dst_reg,       //>o    //register file wr_reg_sel
    exec_addr,          //>o    //data memory access addr
    exec_imm_val,       //>o    //immediate value
    exec_imm_val_vld,   //>o    //immediate value valid
    decode2cpu_ctrl_cmd //>o    //cmd for cpu_ctrl fsm :call, branch, ret, soft_rst, halted, exec_en, fetch_en
);
    //IOs
    input            clk;
    input            reset_;

    input            idecode_en;
    input [7:0]      inst_i;

    output reg [3:0]    exec_ctrl;
    output reg [2:0]    exec_src0_reg;
    output reg [0:0]    exec_src0_reg_rd_en;
    output reg [2:0]    exec_src1_reg;
    output reg [0:0]    exec_src1_reg_rd_en;
    output reg [7:0]    exec_imm_val;
    output reg [0:0]    exec_imm_val_vld;
    output reg [2:0]    exec_dst_reg;
    output reg [11:0]   exec_addr;

    output [6:0]        decode2cpu_ctrl_cmd;

    //regs
    reg [0:0] imm_mode;
    reg [7:0] prev_inst;
    reg [0:0] imm_mode_next;
    reg [0:0] fetch_en_next;

    reg [0:0] exec_en;
    reg [0:0] fetch_en;

    reg [2:0]  exec_src0_reg_next;
    reg        exec_src0_reg_rd_en_next;
    reg [2:0]  exec_src1_reg_next;
    reg        exec_src1_reg_rd_en_next;
    reg [7:0]  exec_dst_reg_next;
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

    reg call;
    reg call_next;
    reg branch;
    reg branch_next;
    reg ret;
    reg ret_next;

    //wires
    wire [7:0] curr_inst;

    assign curr_inst = inst_i;

    assign decode2cpu_ctrl_cmd = {call, branch, ret, soft_rst, halted, exec_en, fetch_en};

    //retimer
    always @(posedge clk) begin
        if(!reset_) begin 
            imm_mode            <= 1'b0;
            prev_inst           <= 8'h00;
            exec_ctrl           <= `EXEC_NOP;
            fetch_en            <= 1'b1;
            exec_addr           <= 12'd0;
            exec_src0_reg       <= 3'd0;
            exec_src0_reg_rd_en <= 1'b0;
            exec_src1_reg       <= 3'd0;
            exec_src1_reg_rd_en <= 1'b0;
            exec_dst_reg        <= 3'd0; 
            exec_imm_val        <= 8'd0;
            exec_imm_val_vld    <= 1'b0;
            exec_en             <= 1'b0;
            halted              <= 1'b0;
            soft_rst            <= 1'b0;
            call                <= 1'b0;
            branch              <= 1'b0;
            ret                 <= 1'b0;
        end
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
            halted              <= halted_next;
            soft_rst            <= soft_rst_next;
            call                <= call_next;
            branch              <= branch_next;
            ret                 <= ret_next;
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
        branch_next = 1'b0;
        call_next = 1'b0;
        ret_next = 1'b0;

        fatal_err = 1'b0;
        unimplemented_err = 1'b0;
        
        if(idecode_en) begin // {
            if(imm_mode) begin // {
                exec_imm_val_vld_next = 1'b1;
                imm_mode_next = 1'b0;
                exec_en_next = 1'b1;
                exec_ctrl_next = `EXEC_NOP;
                casez(`GET_BASE_OP(prev_inst))
                    `MC_CTRL_USR : begin
                        casez(`GET_MC_CTRL_USR_OP(prev_inst)) 
                            `JMP: begin
                                exec_addr_next = ((prev_inst & 8'h07) << 8) | curr_inst;
                                fetch_en_next = 1'b0;
                                branch_next = 1'b1;
                                if(`DEBUG_PRINT) $display("{IDECODE: ADDRESS = %d} ",exec_addr_next);
                            end
                            `CALL: begin 
                                exec_addr_next = ((prev_inst & 8'h07) << 8) | curr_inst;
                                fetch_en_next = 1'b0;
                                call_next = 1'b1;
                                if(`DEBUG_PRINT) $display("{IDECODE: ADDRESS = %d} ",exec_addr_next);
                            end
                            default: begin
                                if(`DEBUG_PRINT) $display("OPCODE: %02x\n",prev_inst);
                                fatal_err = 1'b1;
                            end
                        endcase
                        exec_imm_val_next = curr_inst;
                    end
                    `ADD,
                    `SUB,
                    `AND,
                    `XOR: begin 
                        exec_imm_val_next = curr_inst;
                        if(`DEBUG_PRINT) $display("{IDECODE: IMMEDIATE_VAL = %d} ", exec_imm_val_next);
                    end
                    `LD,
                    `ST: begin
                        exec_addr_next = ((prev_inst & 8'h07) << 8) | curr_inst;
                        if(`DEBUG_PRINT) $display("{IDECODE: ADDRESS = %d} ",exec_addr_next);
                    end
                    default: begin
                        if(`DEBUG_PRINT) $display("OPCODE: %02x\n",prev_inst);
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
                                       if(`DEBUG_PRINT) $display("{IDECODE: NOP} ");
                                       exec_ctrl_next = `EXEC_NOP; 
                                    end
                                    `RET: begin
                                       if(`DEBUG_PRINT) $display("{IDECODE: RET} ");
                                       exec_ctrl_next = `CPU_OPERATION_RET; 
                                       fetch_en_next = 1'b0;
                                       ret_next = 1'b0;
                                    end
                                    `HALT: begin
                                       if(`DEBUG_PRINT) $display("{IDECODE: HALT} ");
                                       fetch_en_next = 1'b0;
                                       halted_next = 1'b1;
                                    end
                                    `RST: begin
                                       if(`DEBUG_PRINT) $display("{IDECODE: RESET} ");
                                       soft_rst_next = 1'b1;
                                    end
                                    `SET_BCZ: begin
                                       if(`DEBUG_PRINT) $display("{IDECODE: SET_BCZ} ");
                                       exec_ctrl_next = `EXEC_IDLE;
                                       unimplemented_err = 1'b1;
                                       //TODO: update control register
                                    end
                                    `SET_BCNZ: begin
                                       if(`DEBUG_PRINT) $display("{IDECODE: SET_BCNZ} ");
                                       exec_ctrl_next = `EXEC_IDLE;
                                       unimplemented_err = 1'b1;
                                       //TODO: update control register
                                    end
                                    `CLR_BC: begin
                                       if(`DEBUG_PRINT) $display("{IDECODE: CLR_BC} ");
                                       exec_ctrl_next = `EXEC_IDLE;
                                       unimplemented_err = 1'b1;
                                       //TODO: update control register
                                    end
                                    default: begin
                                       if(`DEBUG_PRINT) $display("{IDECODE: UNKNOWN} ");
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
                                exec_ctrl_next = `CPU_OPERATION_JMP;
                                if(`DEBUG_PRINT) $display("{IDECODE: JMP} ");
                            end
                            `CALL: begin
                                exec_ctrl_next = `CPU_OPERATION_CALL;
                                if(`DEBUG_PRINT) $display("{IDECODE: CALL} ");
                            end
                            default: begin
                                       if(`DEBUG_PRINT) $display("{IDECODE: UNKNOWN} ");
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
                            if(`DEBUG_PRINT) $display("{IDECODE: ADDI: src0_reg = %d, dst_reg = %d} ", exec_src0_reg_next, exec_dst_reg_next);
                        end
                        else begin
                            exec_src0_reg_next = `GET_REG_PTR0(curr_inst);
                            exec_src0_reg_rd_en_next = 1'b1;
                            exec_src1_reg_next = `GET_REG_PTR1(curr_inst);
                            exec_src1_reg_rd_en_next = 1'b1;
                            exec_dst_reg_next = `GET_REG_PTR1(curr_inst);
                            if(`DEBUG_PRINT) $display("{IDECODE: ADD: src0_reg = %d, src1_reg = %d, dst_reg = %d} ",exec_src0_reg_next, exec_src1_reg_next, exec_dst_reg_next);
                        end
                    end
                    `SUB: begin
                        exec_ctrl_next = `ALU_OPERATION_SUB;
                        if(imm_mode_next) begin
                            exec_src0_reg_next = `GET_REG_PTR0(curr_inst);
                            exec_src0_reg_rd_en_next = 1'b1;
                            exec_dst_reg_next = `GET_REG_PTR1(curr_inst);
                            if(`DEBUG_PRINT) $display("{IDECODE: SUBI: src0_reg = %d, dst_reg = %d} ", exec_src0_reg_next, exec_dst_reg_next);
                        end
                        else begin
                            exec_src0_reg_next = `GET_REG_PTR0(curr_inst);
                            exec_src0_reg_rd_en_next = 1'b1;
                            exec_src1_reg_next = `GET_REG_PTR1(curr_inst);
                            exec_src1_reg_rd_en_next = 1'b1;
                            exec_dst_reg_next = `GET_REG_PTR1(curr_inst);
                            if(`DEBUG_PRINT) $display("{IDECODE: SUB: src0_reg = %d, src1_reg = %d, dst_reg = %d} ",exec_src0_reg_next, exec_src1_reg_next, exec_dst_reg_next);
                        end
                    end
                    `AND: begin
                        exec_ctrl_next = `ALU_OPERATION_AND;
                        if(imm_mode_next) begin
                            exec_src0_reg_next = `GET_REG_PTR0(curr_inst);
                            exec_src0_reg_rd_en_next = 1'b1;
                            exec_dst_reg_next = `GET_REG_PTR1(curr_inst);
                            if(`DEBUG_PRINT) $display("{IDECODE: ANDI: src0_reg = %d, dst_reg = %d} ", exec_src0_reg_next, exec_dst_reg_next);
                        end
                        else begin
                            exec_src0_reg_next = `GET_REG_PTR0(curr_inst);
                            exec_src0_reg_rd_en_next = 1'b1;
                            exec_src1_reg_next = `GET_REG_PTR1(curr_inst);
                            exec_src1_reg_rd_en_next = 1'b1;
                            exec_dst_reg_next = `GET_REG_PTR1(curr_inst);
                            if(`DEBUG_PRINT) $display("{IDECODE: AND: src0_reg = %d, src1_reg = %d, dst_reg = %d} ",exec_src0_reg_next, exec_src1_reg_next, exec_dst_reg_next);
                        end
                    end
                    `OR: begin
                        exec_ctrl_next = `ALU_OPERATION_OR;
                        if(imm_mode_next) begin
                            exec_src0_reg_next = `GET_REG_PTR0(curr_inst);
                            exec_src0_reg_rd_en_next = 1'b1;
                            exec_dst_reg_next = `GET_REG_PTR1(curr_inst);
                            if(`DEBUG_PRINT) $display("{IDECODE: ORI: src0_reg = %d, dst_reg = %d} ", exec_src0_reg_next, exec_dst_reg_next);
                        end
                        else begin
                            exec_src0_reg_next = `GET_REG_PTR0(curr_inst);
                            exec_src0_reg_rd_en_next = 1'b1;
                            exec_src1_reg_next = `GET_REG_PTR1(curr_inst);
                            exec_src1_reg_rd_en_next = 1'b1;
                            exec_dst_reg_next = `GET_REG_PTR1(curr_inst);
                            if(`DEBUG_PRINT) $display("{IDECODE: OR: src0_reg = %d, src1_reg = %d, dst_reg = %d} ",exec_src0_reg_next, exec_src1_reg_next, exec_dst_reg_next);
                        end
                    end
                    `XOR: begin
                        exec_ctrl_next = `ALU_OPERATION_XOR;
                        if(imm_mode_next) begin
                            exec_src0_reg_next = `GET_REG_PTR0(curr_inst);
                            exec_src0_reg_rd_en_next = 1'b1;
                            exec_dst_reg_next = `GET_REG_PTR1(curr_inst);
                            if(`DEBUG_PRINT) $display("{IDECODE: XORI: src0_reg = %d, dst_reg = %d} ", exec_src0_reg_next, exec_dst_reg_next);
                        end
                        else begin
                            exec_src0_reg_next = `GET_REG_PTR0(curr_inst);
                            exec_src0_reg_rd_en_next = 1'b1;
                            exec_src1_reg_next = `GET_REG_PTR1(curr_inst);
                            exec_src1_reg_rd_en_next = 1'b1;
                            exec_dst_reg_next = `GET_REG_PTR1(curr_inst);
                            if(`DEBUG_PRINT) $display("{IDECODE: XOR: src0_reg = %d, src1_reg = %d, dst_reg = %d} ",exec_src0_reg_next, exec_src1_reg_next, exec_dst_reg_next);
                        end
                    end
                    `LD: begin
                        exec_ctrl_next = `MEM_OPERATION_RD;
                        exec_dst_reg_next = `GET_LD_ST_REG_PTR(curr_inst);
                        imm_mode_next = 1'b1;
                        if(`DEBUG_PRINT) $display("{IDECODE: LOAD reg[%d]} ", exec_dst_reg_next);
                    end
                    `ST: begin
                        exec_ctrl_next = `MEM_OPERATION_WR;
                        exec_src0_reg_next = `GET_LD_ST_REG_PTR(curr_inst);
                        exec_src0_reg_rd_en_next = 1'b1;
                        imm_mode_next = 1'b1;
                        if(`DEBUG_PRINT) $display("{IDECODE: STORE reg[%d]} ", exec_dst_reg_next);
                    end
                endcase
                
                exec_en_next = !imm_mode_next;
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
