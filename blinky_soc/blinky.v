module blinky_soc (input reset_, input clk, output LED, output uart_tx);
    wire LED;
    wire uart_tx;
    wire clk;

    reg [31:0] counter;

    always @(posedge clk) begin
        if(!reset_) begin
            counter[31:0] <= 32'd0;
        end
        else begin
            counter[31:0] <= counter[31:0] + 1'b1;
        end
    end
    assign LED=counter[15];
    assign uart_tx=counter[25];
endmodule
