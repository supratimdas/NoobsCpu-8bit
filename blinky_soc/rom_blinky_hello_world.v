/*********************************************************** 
* File Name     : rom_blinky_hello_world.v
* Organization  : NONE
* Creation Date : 05-02-2022
* Last Modified : Sunday 06 February 2022 08:37:44 PM
* Author        : Supratim Das (supratimofficio@gmail.com)
************************************************************/ 

/*=============Description======================
 *
 *
 *
 *
 * ============================================*/
 module rom_blinky_hello_world (
    data,         //< io >
    addr,         //< i
 );

    output  [7:0]    data;
    input   [11:0]   addr;


    reg [7:0] inst;

    assign data = inst;

    always @(*) begin
        case(addr)
            12'd0   : inst = 8'ha0;
            12'd1   : inst = 8'h30;
            12'd2   : inst = 8'h48;
            12'd3   : inst = 8'he0;
            12'd4   : inst = 8'h08;
            12'd5   : inst = 8'ha0;
            12'd6   : inst = 8'h30;
            12'd7   : inst = 8'h65;
            12'd8   : inst = 8'he0;
            12'd9   : inst = 8'h09;
            12'd10  : inst = 8'ha0;
            12'd11  : inst = 8'h30;
            12'd12  : inst = 8'h6c;
            12'd13  : inst = 8'he0;
            12'd14  : inst = 8'h0a;
            12'd15  : inst = 8'ha0;
            12'd16  : inst = 8'h30;
            12'd17  : inst = 8'h6c;
            12'd18  : inst = 8'he0;
            12'd19  : inst = 8'h0b;
            12'd20  : inst = 8'ha0;
            12'd21  : inst = 8'h30;
            12'd22  : inst = 8'h6f;
            12'd23  : inst = 8'he0;
            12'd24  : inst = 8'h0c;
            12'd25  : inst = 8'ha0;
            12'd26  : inst = 8'h30;
            12'd27  : inst = 8'h20;
            12'd28  : inst = 8'he0;
            12'd29  : inst = 8'h0d;
            12'd30  : inst = 8'ha0;
            12'd31  : inst = 8'h30;
            12'd32  : inst = 8'h77;
            12'd33  : inst = 8'he0;
            12'd34  : inst = 8'h0e;
            12'd35  : inst = 8'ha0;
            12'd36  : inst = 8'h30;
            12'd37  : inst = 8'h6f;
            12'd38  : inst = 8'he0;
            12'd39  : inst = 8'h0f;
            12'd40  : inst = 8'ha0;
            12'd41  : inst = 8'h30;
            12'd42  : inst = 8'h72;
            12'd43  : inst = 8'he0;
            12'd44  : inst = 8'h10;
            12'd45  : inst = 8'ha0;
            12'd46  : inst = 8'h30;
            12'd47  : inst = 8'h6c;
            12'd48  : inst = 8'he0;
            12'd49  : inst = 8'h11;
            12'd50  : inst = 8'ha0;
            12'd51  : inst = 8'h30;
            12'd52  : inst = 8'h64;
            12'd53  : inst = 8'he0;
            12'd54  : inst = 8'h12;
            12'd55  : inst = 8'ha0;
            12'd56  : inst = 8'h30;
            12'd57  : inst = 8'h0a;
            12'd58  : inst = 8'he0;
            12'd59  : inst = 8'h13;
            12'd60  : inst = 8'ha0;
            12'd61  : inst = 8'h30;
            12'd62  : inst = 8'h0d;
            12'd63  : inst = 8'he0;
            12'd64  : inst = 8'h14;
            12'd65  : inst = 8'ha0;
            12'd66  : inst = 8'h30;
            12'd67  : inst = 8'h00;
            12'd68  : inst = 8'he0;
            12'd69  : inst = 8'h15;
            12'd70  : inst = 8'hc0;
            12'd71  : inst = 8'h04;
            12'd72  : inst = 8'h70;
            12'd73  : inst = 8'h07;
            12'd74  : inst = 8'he0;
            12'd75  : inst = 8'h04;
            12'd76  : inst = 8'ha0;
            12'd77  : inst = 8'he0;
            12'd78  : inst = 8'h64;
            12'd79  : inst = 8'hb0;
            12'd80  : inst = 8'hff;
            12'd81  : inst = 8'h18;
            12'd82  : inst = 8'h99;
            12'd83  : inst = 8'h18;
            12'd84  : inst = 8'h99;
            12'd85  : inst = 8'h18;
            12'd86  : inst = 8'h99;
            12'd87  : inst = 8'h18;
            12'd88  : inst = 8'h99;
            12'd89  : inst = 8'h18;
            12'd90  : inst = 8'h66;
            12'd91  : inst = 8'h18;
            12'd92  : inst = 8'h99;
            12'd93  : inst = 8'h18;
            12'd94  : inst = 8'h99;
            12'd95  : inst = 8'h18;
            12'd96  : inst = 8'h99;
            12'd97  : inst = 8'h18;
            12'd98  : inst = 8'h99;
            12'd99  : inst = 8'h05;
            12'd100 : inst = 8'h10;
            12'd101 : inst = 8'h4d;
            12'd102 : inst = 8'haf;
            12'd103 : inst = 8'h06;
            12'd104 : inst = 8'hc8;
            12'd105 : inst = 8'h08;
            12'd106 : inst = 8'h07;
            12'd107 : inst = 8'hd0;
            12'd108 : inst = 8'h65;
            12'd109 : inst = 8'h5a;
            12'd110 : inst = 8'h01;
            12'd111 : inst = 8'h05;
            12'd112 : inst = 8'h03;
            12'd113 : inst = 8'h10;
            12'd114 : inst = 8'h6b;
            12'd115 : inst = 8'he8;
            12'd116 : inst = 8'h65;
            12'd117 : inst = 8'h3f;
            12'd118 : inst = 8'h01;
            12'd119 : inst = 8'h55;
            12'd120 : inst = 8'h00;
            12'd121 : inst = 8'h05;
            12'd122 : inst = 8'h04;
            12'd123 : inst = 8'h10;
            12'd124 : inst = 8'h67;
            12'd125 : inst = 8'h01;
            12'd126 : inst = 8'he8;
            12'd127 : inst = 8'h16;
            12'd128 : inst = 8'hf0;
            12'd129 : inst = 8'h17;
            12'd130 : inst = 8'ha5;
            12'd131 : inst = 8'h35;
            12'd132 : inst = 8'hff;
            12'd133 : inst = 8'haa;
            12'd134 : inst = 8'h3a;
            12'd135 : inst = 8'hff;
            12'd136 : inst = 8'h5a;
            12'd137 : inst = 8'h01;
            12'd138 : inst = 8'h05;
            12'd139 : inst = 8'h04;
            12'd140 : inst = 8'h10;
            12'd141 : inst = 8'h88;
            12'd142 : inst = 8'h55;
            12'd143 : inst = 8'h01;
            12'd144 : inst = 8'h05;
            12'd145 : inst = 8'h04;
            12'd146 : inst = 8'h10;
            12'd147 : inst = 8'h85;
            12'd148 : inst = 8'hc8;
            12'd149 : inst = 8'h16;
            12'd150 : inst = 8'hd0;
            12'd151 : inst = 8'h17;
            12'd152 : inst = 8'h01;
            12'd153 : inst = 8'h18;
            12'd154 : inst = 8'h7e;
            12'd155 : inst = 8'h18;
            12'd156 : inst = 8'h7e;
            12'd157 : inst = 8'h18;
            12'd158 : inst = 8'h7e;
            12'd159 : inst = 8'h18;
            12'd160 : inst = 8'h7e;
            12'd161 : inst = 8'h01;
            default: inst = 8'h00;
        endcase
    end

 endmodule
