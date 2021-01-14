/*********************************************************** 
* File Name     : asserts.v
* Description   :
* Organization  : NONE 
* Creation Date : 01-09-2019
* Last Modified : Sunday 03 January 2021 12:03:37 AM IST
* Author        : Supratim Das (supratimofficio@gmail.com)
************************************************************/ 
`timescale 1ns/1ps

module assert_never (clk, test);
    parameter msg = "assert_never_msg";
    input clk;
    input test;
    always @(posedge clk) begin
        if(test) begin
            $display("%c[1;31m",27);
            $display("%s %m",msg);
            $display("%c[0m",27);
            $finish;
        end
    end
endmodule

module assert_always (clk, test);
    parameter msg = "assert_always_msg";
    input clk;
    input test;
    always @(posedge clk) begin
        if(!test) begin
            $display("%c[1;31m",27);
            $display("%s %m",msg);
            $display("%c[0m",27);
            $finish;
        end
    end
endmodule

module assert_impl (clk, antedecent, consequent);
    parameter msg = "assert_impl_msg";
    input clk;
    input antedecent;
    input consequent;
    always @(posedge clk) begin
        if(antedecent && !consequent) begin
            $display("%c[1;31m",27);
            $display("%s %m",msg);
            $display("%c[0m",27);
            $finish;
        end
    end
endmodule

module assert_no_x (clk, test);
    parameter msg = "assert_no_x_msg";
    input clk;
    input test;
    always @(posedge clk) begin
        if(!((test === 1'b1) || (test === 1'b0))) begin
            $display("%c[1;31m",27);
            $display("%s %m",msg);
            $display("%c[0m",27);
            $finish;
        end
    end
endmodule

