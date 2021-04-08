/*
* A simple SoC implementation
* using NoobsCPU core. it has
* a single led as IO, and we
* use a program to constantly
* blink the led.
*/

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

    reg [23:0] counter;
    always @(posedge clk) begin
        counter <= counter + 1'b1;
    end

    assign D0 = i_data[0];
    assign D1 = i_data[1];
    assign D2 = i_data[2];
    assign D3 = i_data[3];
    assign D4 = i_data[4];
    assign D5 = i_data[5];
    assign D6 = i_data[6];
    assign D7 = i_data[7];

    //assign D0 = i_addr[0];
    //assign D1 = i_addr[1];
    //assign D2 = i_addr[2];
    //assign D3 = i_addr[3];
    //assign D4 = i_addr[4];
    //assign D5 = i_addr[5];
    //assign D6 = i_addr[6];
    //assign D7 = i_addr[7];

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


    wire cpu_clk = counter[20];

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
        if((m_addr == 11'd15) && m_wr & m_en) begin
            led_out_next = |m_wr_data;
        end
        else begin
            led_out_next = led_out;
        end
    end

    assign LED = led_out;

    data_mem u_data_mem (
        .clk(cpu_clk),      //< i
        .addr(data_mem_addr),  //< i
        .rd_data(m_rd_data),  //> o
        .wr_data(m_wr_data),  //< i
        .wr(m_en & m_wr),      //< i
        .rd(m_en & m_rd),      //< i
    );

    //memory/io subsystem
    inst_mem u_inst_mem (
        .clk(cpu_clk),     //< i
        .addr(i_addr), //< i
        .rd_data(i_data), //< io >
        .rd(1'b1),     //< i
    );

    assign TEST1 = 0; //prim_rst_; 
    assign TEST2 = 0; //system_reset_; 
    assign TEST3 = 0; //cpu_clk; 
    assign TEST4 = 0; //m_wr; 

    //cpu instance
    noobs_cpu u_noobs_cpu(
        .clk(cpu_clk),                      //<i
        .reset_(system_reset_),         //<i
        .i_data(i_data),                //<i inst_mem_data
        .i_addr(i_addr),                //>o inst_mem_address
        .m_wr_data(m_wr_data),             //>o  data_mem_data wr_data
        .m_rd_data(m_rd_data),             //<i  data_mem_data rd_data
        .m_addr(m_addr),                //>o  data_mem_addr
        .m_rd(m_rd),                    //>o  data_mem_rd enable
        .m_wr(m_wr),                    //>o  data_mem_wr enable
        .m_en(m_en)                     //>   data_mem en
    );

endmodule
