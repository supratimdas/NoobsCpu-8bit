/*********************************************************** 
* File Name     : ifetch.v
* Description   :
* Organization  : NONE 
* Creation Date : 11-05-2019
* Last Modified : Saturday 11 May 2019 10:10:43 PM IST
* Author        : Supratim Das (supratimofficio@gmail.com)
************************************************************/ 

module ifetch(
    clk,        //< i
    reset_,     //< i
    branch,     //< i
    ifetch_en,   //< i
    inst_i,     //< i
    tgt_addr,   //< i
    inst_o,     //> o
    next_addr,  //> o
    inst_addr   //> o
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
    assign pc_addr_next = (branch) ? tgt_addr : next_addr;
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
