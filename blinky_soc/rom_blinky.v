/*********************************************************** 
* File Name     : rom_blinky.v
* Organization  : NONE
* Creation Date : 05-02-2022
* Last Modified : Sunday 06 February 2022 03:22:52 PM
* Author        : Supratim Das (supratimofficio@gmail.com)
************************************************************/ 

/*=============Description======================
 *
 *
 *
 *
 * ============================================*/
 module rom_blinky (
    data,         //< io >
    addr,         //< i
 );

    output  [7:0]    data;
    input   [11:0]   addr;


    reg [7:0] inst;

    assign data = inst;

    always @(*) begin
        case(addr)
            12'd0 : inst = 8'hc0; 
            12'd1 : inst = 8'h04;
            12'd2 : inst = 8'h70;
            12'd3 : inst = 8'h07;
            12'd4 : inst = 8'he0;
            12'd5 : inst = 8'h04;
            12'd6 : inst = 8'ha0;
            12'd7 : inst = 8'he0;
            12'd8 : inst = 8'h64;
            12'd9 : inst = 8'hb0;
            12'd10: inst = 8'hff;
            12'd11: inst = 8'h18;
            12'd12: inst = 8'h40;
            12'd13: inst = 8'h18;
            12'd14: inst = 8'h40;
            12'd15: inst = 8'h05;
            12'd16: inst = 8'h10;
            12'd17: inst = 8'h07;
            12'd18: inst = 8'h05;
            12'd19: inst = 8'h10;
            12'd20: inst = 8'h07;
            12'd21: inst = 8'h05;
            12'd22: inst = 8'h10;
            12'd23: inst = 8'h07;
            12'd24: inst = 8'h05;
            12'd25: inst = 8'h10;
            12'd26: inst = 8'h07;
            12'd27: inst = 8'h05;
            12'd28: inst = 8'h10;
            12'd29: inst = 8'h07;
            12'd30: inst = 8'h05;
            12'd31: inst = 8'h10;
            12'd32: inst = 8'h07;
            12'd33: inst = 8'h05;
            12'd34: inst = 8'h10;
            12'd35: inst = 8'h07;
            12'd36: inst = 8'h00;
            12'd37: inst = 8'he8;
            12'd38: inst = 8'h16;
            12'd39: inst = 8'hf0;
            12'd40: inst = 8'h17;
            12'd41: inst = 8'ha5;
            12'd42: inst = 8'h35;
            12'd43: inst = 8'hff;
            12'd44: inst = 8'haa;
            12'd45: inst = 8'h3a;
            12'd46: inst = 8'hff;
            12'd47: inst = 8'h5a;
            12'd48: inst = 8'h01;
            12'd49: inst = 8'h05;
            12'd50: inst = 8'h04;
            12'd51: inst = 8'h10;
            12'd52: inst = 8'h2f;
            12'd53: inst = 8'h55;
            12'd54: inst = 8'h01; 
            12'd55: inst = 8'h05;
            12'd56: inst = 8'h04;
            12'd57: inst = 8'h10;
            12'd58: inst = 8'h2c;
            12'd59: inst = 8'hc8;
            12'd60: inst = 8'h16;
            12'd61: inst = 8'hd0;
            12'd62: inst = 8'h17;
            12'd63: inst = 8'h01;
            12'd64: inst = 8'h18;
            12'd65: inst = 8'h25;
            12'd66: inst = 8'h18;
            12'd67: inst = 8'h25;
            12'd68: inst = 8'h18;
            12'd69: inst = 8'h25;
            12'd70: inst = 8'h18;
            12'd71: inst = 8'h25;
            12'd72: inst = 8'h01;
            default: inst = 8'h00;
        endcase
    end

 endmodule
