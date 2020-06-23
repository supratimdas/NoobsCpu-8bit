/*********************************************************** 
* File Name     : register_file.v
* Description   : this is the register file model
* Organization  : NONE 
* Creation Date : 01-09-2019
* Last Modified : Friday 19 June 2020 06:37:57 PM IST
* Author        : Supratim Das (supratimofficio@gmail.com)
************************************************************/ 

//Short summary
//This is a simple register file with 2 read ports
//and a write port. The register width is 8bit wide

module reg_file (
    clk ,       //<i
    //reset_,     //<i
    rd_sel_0,   //<i
    rd_en_0,    //<i
    rd_sel_1,   //<i
    rd_en_1,    //<i
    wr_sel,     //<i
    wr_en,      //<i
    
    wr_data,    //<i

    rd_data_0,  //>o
    rd_data_1   //>0
);
    input clk;
    //input reset_;

    input [2:0] rd_sel_0;
    input [2:0] rd_sel_1;
    input [2:0] wr_sel;
    input rd_en_0;
    input rd_en_1;
    input wr_en;

    input [7:0] wr_data;
    
    output reg [7:0] rd_data_0;
    output reg [7:0] rd_data_1;

    reg [7:0] reg0;
    reg [7:0] reg1;
    reg [7:0] reg2;
    reg [7:0] reg3;
    reg [7:0] reg4;
    reg [7:0] reg5;
    reg [7:0] reg6;
    reg [7:0] reg7;


    reg [7:0] rd_data_0_next;
    reg [7:0] rd_data_1_next;

    //read port 0
    always @(*) begin
        if(rd_en_0 & wr_en & (rd_sel_0 == wr_sel)) begin //to avoid RAW hazards in pipeline
            rd_data_0_next = wr_data;
        end
        else if(rd_en_0) begin
            casez(rd_sel_0)
                3'd0: rd_data_0_next = reg0;
                3'd1: rd_data_0_next = reg1;
                3'd2: rd_data_0_next = reg2;
                3'd3: rd_data_0_next = reg3;
                3'd4: rd_data_0_next = reg4;
                3'd5: rd_data_0_next = reg5;
                3'd6: rd_data_0_next = reg6;
                3'd7: rd_data_0_next = reg7;
            endcase
        end
        else begin
            rd_data_0_next = 8'd0;
        end
    end

    always @(posedge clk) begin
        rd_data_0 <= rd_data_0_next;
    end

    //read port 1
    always @(*) begin
        if(rd_en_1 & wr_en & (rd_sel_1 == wr_sel)) begin //to avoid RAW hazards in pipeline
            rd_data_1_next = wr_data;
        end
        else if(rd_en_1) begin
            casez(rd_sel_1)
                3'd0: rd_data_1_next = reg0;
                3'd1: rd_data_1_next = reg1;
                3'd2: rd_data_1_next = reg2;
                3'd3: rd_data_1_next = reg3;
                3'd4: rd_data_1_next = reg4;
                3'd5: rd_data_1_next = reg5;
                3'd6: rd_data_1_next = reg6;
                3'd7: rd_data_1_next = reg7;
            endcase
        end
        else begin
            rd_data_1_next = 8'd0;
        end
    end

    always @(posedge clk) begin
        rd_data_1 <= rd_data_1_next;
    end


    //wr_port
    always @(posedge clk) begin
        if(wr_en) begin
            casez(wr_sel)
                3'd0: reg0 <= wr_data;
                3'd1: reg1 <= wr_data;
                3'd2: reg2 <= wr_data;
                3'd3: reg3 <= wr_data;
                3'd4: reg4 <= wr_data;
                3'd5: reg5 <= wr_data;
                3'd6: reg6 <= wr_data;
                3'd7: reg7 <= wr_data;
            endcase
        end
    end

endmodule
