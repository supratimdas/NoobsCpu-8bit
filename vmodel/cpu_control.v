/*********************************************************** 
* File Name     : cpu_control.v
* Description   :
* Organization  : NONE 
* Creation Date : 10-09-2019
* Last Modified : Thursday 14 January 2021 09:47:03 PM IST
* Author        : Supratim Das (supratimofficio@gmail.com
************************************************************/ 
`timescale 1ns/1ps

`define INIT            0
`define CPU_RUN         1
`define CPU_HALT        2
`define CPU_BRANCH      3
`define CPU_STACK_OP    5

module cpu_control (
    clk,                    //<i
    reset_,                 //<i
    decode2cpu_ctrl_cmd,    //<i    call, branch, ret, soft_rst, halted, exec_en, fetch_en
    cbr_status,             //>o    call, branch, return

    ifetch_en,              //>o
    execute_en,             //>o
    idecode_en,             //>o
    pc_reset,               //>o
    pc_branch               //>o
);
    input               clk;
    input               reset_;
    input [6:0]         decode2cpu_ctrl_cmd;
    output [2:0]        cbr_status;

    output              ifetch_en;
    output              execute_en;
    output              idecode_en;
    output              pc_branch;
    output              pc_reset;

    //regs
    reg [3:0]           cpu_state;
    reg [3:0]           cpu_state_next;
    
    //wires
    wire soft_rst;
    wire halted;
    wire exec_en;
    wire fetch_en;

    wire call;
    wire branch;
    wire ret;

    assign {call, branch, ret, soft_rst, halted, exec_en, fetch_en} = decode2cpu_ctrl_cmd;

    assign cbr_status = {call, branch, ret};

    assign ifetch_en = fetch_en && (cpu_state != `CPU_STACK_OP); 
    
    assign idecode_en = (cpu_state == `CPU_RUN);

    assign execute_en = exec_en; 

    assign pc_reset = (cpu_state_next == `INIT);

    assign pc_branch = (cpu_state_next == `CPU_BRANCH);

    //CPU_STATE FSM
    always @(posedge clk) begin
        if(!reset_) begin
            cpu_state <= `INIT;
        end
        else begin
            cpu_state   <= cpu_state_next;
        end
    end

    always @(*) begin
        cpu_state_next = cpu_state;

        case(cpu_state)
            `INIT: begin
                cpu_state_next = `CPU_RUN;
            end
            `CPU_RUN: begin
                if(halted) begin
                    cpu_state_next = `CPU_HALT;
                end
                else if(soft_rst) begin
                    cpu_state_next = `INIT;
                end
                else begin
                    case({call, branch, ret})
                        3'b001: begin
                            cpu_state_next = `CPU_STACK_OP;
                        end
                        3'b010: begin
                            cpu_state_next = `CPU_BRANCH;
                        end
                        3'b100: begin
                            cpu_state_next = `CPU_STACK_OP;
                        end
                        default: begin
                            cpu_state_next = `CPU_RUN;
                        end
                    endcase
                end
            end
            `CPU_HALT: begin
                cpu_state_next = `CPU_HALT;
            end
            `CPU_BRANCH: begin
                cpu_state_next = `CPU_RUN;
            end
            `CPU_STACK_OP: begin
                if(branch) begin
                    cpu_state_next = `CPU_BRANCH;
                end
                else begin
                    cpu_state_next = `CPU_STACK_OP;
                end
            end
        endcase
    end


    assert_never #("call branch ret flags cannot be set all at the same time") u_assert_never_1 (clk,(call & branch & ret)); 
endmodule
