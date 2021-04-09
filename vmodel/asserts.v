/*********************************************************** 
* File Name     : asserts.v
* Description   :
* Organization  : NONE 
* Creation Date : 01-09-2019
* Last Modified : Friday 09 April 2021 06:43:46 PM
* Author        : Supratim Das (supratimofficio@gmail.com)
************************************************************/ 
`timescale 1ns/1ps

module assert_never (clk, reset_, test);
    parameter msg = "assert_never_msg";
    input clk;
    input reset_;
    input test;
    always @(posedge clk) begin
        if(reset_ === 1) begin
            if(test) begin
                $display("%c[1;31m",27);
                $display("%s %m",msg);
                $display("%c[0m",27);
                $finish;
            end
        end
    end
endmodule

module assert_always (clk, reset_, test);
    parameter msg = "assert_always_msg";
    input clk;
    input reset_;
    input test;
    always @(posedge clk) begin
        if(reset_ === 1) begin
            if(!test) begin
                $display("%c[1;31m",27);
                $display("%s %m",msg);
                $display("%c[0m",27);
                $finish;
            end
        end
    end
endmodule

module assert_impl (clk, reset_, antedecent, consequent);
    parameter msg = "assert_impl_msg";
    input clk;
    input reset_;
    input antedecent;
    input consequent;
    always @(posedge clk) begin
        if(reset_ === 1) begin
            if(antedecent && !consequent) begin
                $display("%c[1;31m",27);
                $display("%s %m",msg);
                $display("%c[0m",27);
                $finish;
            end
        end
    end
endmodule

module assert_no_x (clk, reset_, test);
    parameter msg = "assert_no_x_msg";
    input clk;
    input reset_;
    input test;
    always @(posedge clk) begin
        if(reset_ === 1) begin
            if(!((test === 1'b1) || (test === 1'b0))) begin
                $display("%c[1;31m",27);
                $display("%s %m",msg);
                $display("%c[0m",27);
                $finish;
            end
        end
    end
endmodule

