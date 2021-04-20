/*
* A simple SoC implementation
* using NoobsCPU core. it has
* a single led as IO (ADDRESS:0x100)
*, and we use a program to constantly
* blink the led, and an UART TX module
* (ADDRESS:0x101) for text output
*/

`define LED_M_ADDR 11'd100
`define UART_TX_M_ADDR 11'd101

module blinky_soc (
    clk,
    LED,
    TEST1,
    TEST2,
    TEST3,
    TEST4,
    D0,
    D1,
    D2,
    D3,
    D4,
    D5,
    D6,
    D7
);
    //IOs
    input   clk;
    output  LED;

    output TEST1; 
    output TEST2; 
    output TEST3; 
    output TEST4; 

    output D0;
    output D1;
    output D2;
    output D3;
    output D4;
    output D5;
    output D6;
    output D7;

    reg [25:0] counter;
    always @(posedge clk) begin
        counter <= counter + 1'b1;
    end

    //assign D0 = i_data[0];
    //assign D1 = i_data[1];
    //assign D2 = i_data[2];
    //assign D3 = i_data[3];
    //assign D4 = i_data[4];
    //assign D5 = i_data[5];
    //assign D6 = i_data[6];
    //assign D7 = i_data[7];

    //assign D0 = i_addr[0];
    //assign D1 = i_addr[1];
    //assign D2 = i_addr[2];
    //assign D3 = i_addr[3];
    //assign D4 = i_addr[4];
    //assign D5 = i_addr[5];
    //assign D6 = i_addr[6];
    //assign D7 = i_addr[7];

    //assign D0 = m_rd_data[0];
    //assign D1 = m_rd_data[1];
    //assign D2 = m_rd_data[2];
    //assign D3 = m_rd_data[3];
    //assign D4 = m_rd_data[4];
    //assign D5 = m_rd_data[5];
    //assign D6 = m_rd_data[6];
    //assign D7 = m_rd_data[7];

    //assign D0 = REG3[0];
    //assign D1 = REG3[1];
    //assign D2 = REG3[2];
    //assign D3 = REG3[3];
    //assign D4 = REG3[4];
    //assign D5 = REG3[5];
    //assign D6 = REG3[6];
    //assign D7 = REG3[7];

    //assign D0 = REG_WR_DATA[0];
    //assign D1 = REG_WR_DATA[1];
    //assign D2 = REG_WR_DATA[2];
    //assign D3 = REG_WR_DATA[3];
    //assign D4 = REG_WR_DATA[4];
    //assign D5 = REG_WR_DATA[5];
    //assign D6 = REG_WR_DATA[6];
    //assign D7 = REG_WR_DATA[7];

    //assign D0 = data_mem_addr[0];
    //assign D1 = data_mem_addr[1];
    //assign D2 = data_mem_addr[2];
    //assign D3 = data_mem_addr[3];
    //assign D4 = data_mem_addr[4];
    //assign D5 = data_mem_addr[5];
    //assign D6 = data_mem_addr[6];
    //assign D7 = data_mem_addr[7];


    assign D0 = tx;
    assign D1 = tx;
    assign D2 = 0;//tx_data_out[2];
    assign D3 = 0;//tx_data_out[3];
    assign D4 = 0;//tx_data_out[4];
    assign D5 = 0;//tx_data_out[5];
    assign D6 = 0;//tx_data_out[6];
    assign D7 = 0;//tx_data_out[7];

    //===========power-on reset generation logic===============//
    reg[23:0] prim_reset_gen_cnt;
    reg[23:0] sec_reset_gen_cnt;
    always @(posedge clk) begin
        if(prim_reset_gen_cnt != 24'hffffff)
            prim_reset_gen_cnt <= prim_reset_gen_cnt + 1'b1;
    end

    wire prim_rst_;
    assign prim_rst_ = (prim_reset_gen_cnt == 24'hffffff);

    always @(posedge clk) begin
        if(!prim_rst_) begin
            sec_reset_gen_cnt <= 24'h0;
        end
        else if(sec_reset_gen_cnt != 24'hffffff) begin
            sec_reset_gen_cnt <= sec_reset_gen_cnt + 1'b1;
        end
    end

    wire sec_rst_;
    assign sec_rst_ = (sec_reset_gen_cnt == 24'hffffff);

    wire system_reset_;
    assign system_reset_ = prim_rst_ & sec_rst_;


    ///////////////////////////////////////////////////////////////////


    wire cpu_clk =  clk; //counter[1];

    wire [7:0] i_data;
    wire [7:0] m_rd_data;
    wire [7:0] m_wr_data;

    wire [10:0] m_addr;
    wire [10:0] i_addr;

    wire m_rd;
    wire m_wr;
    wire m_en;

    //inst_mem instance
    wire [11:0] data_mem_addr;
    assign data_mem_addr = (m_addr - 8);


    ////////////////////////GPIO//////////////////////
    reg led_out;
    reg led_out_next;

    always @(posedge cpu_clk) begin
        if(!system_reset_) begin
            led_out <= 1'b1;
        end
        else begin
            led_out <= led_out_next;
        end
    end

    always @(*) begin
        if((m_addr == `LED_M_ADDR) && m_wr & m_en) begin
            led_out_next = |m_wr_data;
        end
        else begin
            led_out_next = led_out;
        end
    end

    assign LED = led_out;
    ///////////////////////////////////////////////////

    ///////////////////////UART////////////////////////
    wire clk50m;
    wire txclk_en;
    wire tx;

    pll u_pll(
	    .clock_in(clk),
	    .clock_out(clk50m),
	    .locked()
	);

    baud_rate_gen u_br_gen(
        .clk_50m(clk50m),
		.rxclk_en(),
		.txclk_en(txclk_en)
    );

    reg [7:0] tx_data_out;
    reg [7:0] tx_data_out_next;

    reg tx_data_wr;
    reg tx_data_wr_next;
    always @(posedge cpu_clk) begin
        if(!system_reset_) begin
            tx_data_out <= 8'd0;
            tx_data_wr  <= 1'b0;
        end
        else begin
            tx_data_out <= tx_data_out_next;
            tx_data_wr  <= tx_data_wr_next;
        end
    end

    always @(*) begin
        if((m_addr == `UART_TX_M_ADDR) && m_wr & m_en) begin
            tx_data_out_next = m_wr_data;
            tx_data_wr_next = 1'b1;
        end
        else begin
            tx_data_out_next = tx_data_out;
            tx_data_wr_next = 1'b0;
        end
    end

    reg tx_wr;
    reg tx_wr_q;
    always @(posedge clk50m) begin
        if(!system_reset_) begin
            tx_wr   <= 1'b0;
            tx_wr_q <= 1'b0;
        end
        else begin
            tx_wr     <= tx_data_wr;
            tx_wr_q   <= tx_wr;
        end
    end

    wire wr_en;
    assign wr_en = tx_wr & (tx_wr ^ tx_wr_q);

    wire tx_busy;

    wire [7:0] cpu_rd_data;
    always @(*) begin
        if((m_addr == `UART_TX_M_ADDR) & m_rd & m_en) begin
            cpu_rd_data = {7'd0,tx_busy};
        end
        else begin
            cpu_rd_data = m_rd_data;
        end
    end

    transmitter u_tx(
           .din(tx_data_out),
		   .wr_en(wr_en),
		   .clk_50m(clk50m),
		   .clken(txclk_en),
		   .tx(tx),
		   .tx_busy(tx_busy)
     );
     ////////////////////////////////////////////////////


    data_mem u_data_mem (
        .clk(cpu_clk),      //< i
        .addr(data_mem_addr),  //< i
        .rd_data(m_rd_data),  //> o
        .wr_data(m_wr_data),  //< i
        .wr(m_wr),      //< i
        .rd(m_rd),      //< i
    );

    //memory/io subsystem
    inst_mem u_inst_mem (
        .clk(cpu_clk),     //< i
        .addr(i_addr), //< i
        .rd_data(i_data), //< io >
        .rd(1'b1),     //< i
    );

    assign TEST1 = prim_rst_; 
    assign TEST2 = system_reset_;
    assign TEST3 = 0;//cpu_clk;
    assign TEST4 = 0;//m_rd;

    wire [7:0] REG0;
    wire [7:0] REG1;
    wire [7:0] REG2;
    wire [7:0] REG3;
    wire [7:0] REG_WR_DATA;
    wire [1:0] REG_WR_SEL;
    wire [0:0] REG_WR_EN;
    //cpu instance
    noobs_cpu u_noobs_cpu(
        .clk(cpu_clk),                      //<i
        ////////debug ports///////////
        .REG0(REG0),
        .REG1(REG1),
        .REG2(REG2),
        .REG3(REG3),
        .REG_WR_DATA(REG_WR_DATA),
        .REG_WR_SEL(REG_WR_SEL),
        .REG_WR_EN(REG_WR_EN),
        //////////////////////////////
        .reset_(system_reset_),         //<i
        .i_data(i_data),                //<i inst_mem_data
        .i_addr(i_addr),                //>o inst_mem_address
        .m_wr_data(m_wr_data),             //>o  data_mem_data wr_data
        .m_rd_data(cpu_rd_data),             //<i  data_mem_data rd_data
        .m_addr(m_addr),                //>o  data_mem_addr
        .m_rd(m_rd),                    //>o  data_mem_rd enable
        .m_wr(m_wr),                    //>o  data_mem_wr enable
        .m_en(m_en)                     //>   data_mem en
    );

endmodule
