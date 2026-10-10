/*********************************************************** 
* File Name     : asserts.v
* Description   : simulation time assertions
* Organization  : NONE 
* Creation Date : 01-09-2019
* Last Modified : Tuesday 20 April 2021 10:33:03 AM
* Author        : Supratim Das (supratimofficio@gmail.com)
************************************************************/ 
`timescale 1ns/1ps

/*
* used to check that a condition must never happen
*/
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

/*
* used to check that a condition must always be true
*/
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


/*
* Used to check for an implication rule
* if condition_1 == TRUE then condition_2 must also be true 
*/
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

/*
* Used to check for X signals, especially on control lines
*/
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

