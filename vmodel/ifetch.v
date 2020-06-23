/*********************************************************** 
* File Name     : ifetch.v
* Description   : instruction fetch unit
* Organization  : NONE 
* Creation Date : 11-05-2019
* Last Modified : Tuesday 23 June 2020 02:06:45 PM IST
* Author        : Supratim Das (supratimofficio@gmail.com)
************************************************************/ 

//Short summary:
//this module implements the instruction fetch logic.
//this has the program_counter implementation

module ifetch(
    clk,        //< i
    reset_,     //< i
    branch,     //< i branch indication from ctrl unit
    ifetch_en,  //< i ifetch_en indiaction from ctrl unit
    inst_i,     //< i instruction input from inst_mem
    tgt_addr,   //< i tgt branch addr
    inst_o,     //> o instruction output to decode unit
    next_addr,  //> o next_addr 
    inst_addr   //> o addr for instruction memory 
);
    //IOs
    input           clk;
    input           reset_;

    input           branch;
    input           ifetch_en;

    input [7:0]     inst_i;
    input [11:0]    tgt_addr;

    output [7:0]    inst_o;
    output [11:0]   next_addr;
    output [11:0]   inst_addr;
    
    //regs
    reg [11:0]  PC;
    reg [7:0]   inst_reg;

    //wires
    wire [11:0] pc_addr_next;
    wire [7:0] inst;

    //Program Counter implementation
    always @(posedge clk)   begin
        if(!reset_) begin
            PC[11:0]    <= 12'd0;
        end
        else begin
            PC[11:0]    <= pc_addr_next[11:0]; 
        end
    end

    assign next_addr = PC + 1'b1; 
    assign pc_addr_next = (ifetch_en) ? ((branch) ? tgt_addr : next_addr) : PC;
    assign inst_addr = pc_addr_next;    //address for inst mem

    //registering instruction from instruction mem
    always @(posedge clk)   begin
        if(!reset_) begin
            inst_reg[7:0]   <= 8'd0;
        end
        else begin
            inst_reg[7:0]   <= inst;
        end
    end

    assign inst[7:0] = (ifetch_en) ? inst_i[7:0] : inst_reg[7:0];

    assign inst_o[7:0] = inst_reg[7:0];
endmodule
