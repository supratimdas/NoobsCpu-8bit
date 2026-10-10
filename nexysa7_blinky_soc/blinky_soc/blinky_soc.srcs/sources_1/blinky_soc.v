/*
 * A simple SoC implementation
 * using NoobsCPU core. it has
 * a single led as IO (ADDRESS:0x100)
 * , and we use a program to constantly
 * blink the led, and an UART TX module
 * (ADDRESS:0x101) for text output
 * also prints the same in VGA character display. same address as UART
 */

//------------------------------------------------------------------------------
// Memory-mapped IO addresses
//------------------------------------------------------------------------------
`define LED_M_ADDR              11'd100
`define UART_TX_M_ADDR          11'd101
`define VGA_CTRL_REG_M_ADDR     11'd102
`define VGA_ROW_M_ADDR          11'd103
`define VGA_COL_M_ADDR          11'd104
`define VGA_CHAR_DATA_M_ADDR    11'd105

//------------------------------------------------------------------------------
// VGA control modes
//------------------------------------------------------------------------------
`define VGA_MODE_AUTO_INCR      2'd0
`define VGA_MODE_CLEAR_SCREEN   2'd1
`define VGA_MODE_PROG           2'd2

//------------------------------------------------------------------------------
// VGA character display dimensions
//------------------------------------------------------------------------------
`define VGA_NUM_ROWS            30
`define VGA_NUM_COLS            40

`define xilinx


module blinky_soc (
    reset_,
    clk,
    LED,
    uart_tx,
    VGA_R,
    VGA_G,
    VGA_B,
    VGA_HS,
    VGA_VS,
    SW
);

    //--------------------------------------------------------------------------
    // IOs
    //--------------------------------------------------------------------------
    input           reset_;
    input           clk;
    input  [15:0]   SW;
    output [15:0]   LED;
    output          uart_tx;
    output [2:0]    VGA_R;
    output [2:0]    VGA_G;
    output [2:0]    VGA_B;
    output [0:0]    VGA_HS;
    output [0:0]    VGA_VS;

    wire [1:0] red;
    wire [1:0] grn;
    wire [1:0] blu;
    wire       hs;
    wire       vs;

    reg [31:0] counter;

    assign VGA_R[2:0] = {1'b0, red[1:0]};
    assign VGA_G[2:0] = {1'b0, grn[1:0]};
    assign VGA_B[2:0] = {1'b0, blu[1:0]};
    assign VGA_HS     = hs;
    assign VGA_VS     = vs;

    //--------------------------------------------------------------------------
    // Free running counter (used as clock divider)
    //--------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!reset_) begin
            counter[31:0] <= 0;
        end
        else begin
            counter[31:0] <= counter[31:0] + 1'b1;
        end
    end

    wire system_reset_;
    assign system_reset_ = reset_;


    ///////////////////////////////////////////////////////////////////
    // CPU clock
    ///////////////////////////////////////////////////////////////////


    wire cpu_clk = counter[5];


    wire [7:0]  i_data;
    wire [7:0]  m_rd_data;
    wire [7:0]  m_wr_data;

    wire [10:0] m_addr;
    wire [10:0] i_addr;

    wire        m_rd;
    wire        m_wr;
    wire        m_en;

    //inst_mem instance
    wire [11:0] data_mem_addr;
    assign data_mem_addr = (m_addr - 8);


    ///////////////////////////////////////////////////////////////////
    // GPIO
    ///////////////////////////////////////////////////////////////////
    reg led_out;
    reg led_out_next;

    always @(posedge cpu_clk) begin
        if (!system_reset_) begin
            led_out <= 1'b1;
        end
        else begin
            led_out <= led_out_next;
        end
    end

    always @(*) begin
        if ((m_addr == `LED_M_ADDR) && m_wr & m_en) begin
            led_out_next = |m_wr_data;
        end
        else begin
            led_out_next = led_out;
        end
    end


    ///////////////////////////////////////////////////////////////////
    // UART
    ///////////////////////////////////////////////////////////////////
    wire txclk_en;
    wire tx;
    assign uart_tx = tx;

    `ifdef lattice
    pll u_pll (
        .clock_in   (clk),
        .clock_out  (clk50m),
        .locked     ()
    );
    `endif
    `ifdef xilinx
    assign clk50m = counter[0];
    `endif

    reg clk25m;
    always @(posedge clk50m) begin
        clk25m <= !clk25m;
    end

    baud_rate_gen u_br_gen (
        .clk_50m    (clk50m),
        .rxclk_en   (),
        .txclk_en   (txclk_en)
    );

    reg [7:0] tx_data_out;
    reg [7:0] tx_data_out_next;

    reg       tx_data_wr;
    reg       tx_data_wr_next;

    always @(posedge cpu_clk) begin
        if (!system_reset_) begin
            tx_data_out <= 8'd0;
            tx_data_wr  <= 1'b0;
        end
        else begin
            tx_data_out <= tx_data_out_next;
            tx_data_wr  <= tx_data_wr_next;
        end
    end

    always @(*) begin
        if ((m_addr == `UART_TX_M_ADDR) && m_wr && m_en) begin
            tx_data_out_next = m_wr_data;
            tx_data_wr_next  = 1'b1;
        end
        else begin
            tx_data_out_next = tx_data_out;
            tx_data_wr_next  = 1'b0;
        end
    end

    wire tx_busy;

    reg [7:0] cpu_rd_data;
    always @(*) begin
        if ((m_addr == `UART_TX_M_ADDR) && m_rd && m_en) begin
            cpu_rd_data = {7'd0, tx_busy};
        end
        else begin
            cpu_rd_data = m_rd_data;
        end
    end

    transmitter u_tx (
        .din        (tx_data_out),
        .wr_en      (tx_data_wr),
        .clk_50m    (clk50m),
        .clken      (txclk_en),
        .tx         (tx),
        .tx_busy    (tx_busy)
    );


    ///////////////////////////////////////////////////////////////////
    // VGA
    ///////////////////////////////////////////////////////////////////
    wire newline     = ((m_addr == `UART_TX_M_ADDR) && m_wr && m_en && ((m_wr_data == 8'd13)));
    wire disp_wr_en  =  (m_addr == `UART_TX_M_ADDR) && m_wr && m_en /*&& (m_wr_data != 8'd10)*/ && (m_wr_data != 8'd13) && (m_wr_data != 8'd0);

    wire vga_ctrl_update = ((m_addr == `VGA_CTRL_REG_M_ADDR)  && m_wr && m_en);
    wire vga_row_update  = ((m_addr == `VGA_ROW_M_ADDR)       && m_wr && m_en);
    wire vga_col_update  = ((m_addr == `VGA_COL_M_ADDR)       && m_wr && m_en);
    wire vga_char_update = ((m_addr == `VGA_CHAR_DATA_M_ADDR) && m_wr && m_en);

    reg [1:0] vga_ctrl;
    reg [4:0] row;
    reg [5:0] col;
    reg [7:0] vga_char_data;

    reg [4:0] vga_clr_row_addr;
    reg [5:0] vga_clr_col_addr;

    reg       newline_q;
    wire      LF = newline & (newline ^ newline_q); //a Line Feed pulse

    always @(posedge cpu_clk) begin
        if (!system_reset_) begin
            col[5:0]            <= 0;
            row[4:0]            <= 0;
            vga_ctrl[1:0]       <= `VGA_MODE_PROG;
            vga_char_data[7:0]  <= 0;
            vga_clr_row_addr    <= 0;
            vga_clr_col_addr    <= 0;
        end
        else begin
            if (vga_ctrl_update) begin
                vga_ctrl[1:0] <= m_wr_data[1:0];
                if (m_wr_data[1:0] == `VGA_MODE_CLEAR_SCREEN) begin
                    vga_clr_row_addr <= 0;
                    vga_clr_col_addr <= 0;
                end
            end

            //go through the rows/address to clear
            if (vga_clr_row_addr < `VGA_NUM_ROWS) begin
                if (vga_clr_col_addr < `VGA_NUM_COLS) begin
                    vga_clr_col_addr <= vga_clr_col_addr + 1'b1;
                end

                if (vga_clr_col_addr == (`VGA_NUM_COLS-1)) begin
                    vga_clr_row_addr <= vga_clr_row_addr + 1'b1;
                    vga_clr_col_addr <= 0;
                end
            end

            if (vga_row_update && (vga_ctrl[1:0] == `VGA_MODE_PROG)) begin
                row[4:0] <= m_wr_data[5:0];
            end

            if (vga_col_update && (vga_ctrl[1:0] == `VGA_MODE_PROG)) begin
                col[5:0] <= m_wr_data[5:0];
            end

            if (vga_col_update && (vga_ctrl[1:0] == `VGA_MODE_PROG)) begin
                vga_char_data[7:0] <= m_wr_data[7:0];
            end

            if ((vga_ctrl[1:0] == `VGA_MODE_AUTO_INCR) && (disp_wr_en || LF)) begin
                if ((col == (`VGA_NUM_COLS-1)) || LF) begin
                    col[5:0] <= 0;
                end
                else begin
                    col[5:0] <= col[5:0] + 1'b1;
                end
            end

            if ((vga_ctrl[1:0] == `VGA_MODE_AUTO_INCR) && LF) begin
                if (row[4:0] == ((`VGA_NUM_ROWS-1))) begin
                    row[4:0] <= 0;
                end
                else begin
                    row[4:0] <= row[4:0] + 1'b1;
                end
            end
        end

        newline_q <= newline;
    end


    wire [4:0] final_row         = (vga_ctrl[1:0] == `VGA_MODE_CLEAR_SCREEN) ? vga_clr_row_addr : row;
    wire [5:0] final_col         = (vga_ctrl[1:0] == `VGA_MODE_CLEAR_SCREEN) ? vga_clr_col_addr : col;
    wire [0:0] final_disp_wr_en  = (vga_ctrl[1:0] == `VGA_MODE_CLEAR_SCREEN) ? 1'b1 : disp_wr_en;
    wire [7:0] final_char_data   = (vga_ctrl[1:0] == `VGA_MODE_CLEAR_SCREEN) ? 8'd32 :
                                   (vga_ctrl[1:0] == `VGA_MODE_AUTO_INCR)    ? tx_data_out : vga_char_data;

    assign LED[15:14] = vga_ctrl[1:0] | SW[15:14];
    assign LED[13:1]  = SW[13:1] | {5'd0, final_char_data[7:0]};
    assign LED[0]     = led_out | SW[0];
    
    //whatever uart prints out, also comes in vga
    vga40x30x2 u_character_disp (
        .clk25m     (clk25m),
        .red        (red),
        .grn        (grn),
        .blu        (blu),
        .hs         (hs),
        .vs         (vs),
        .fr         (),
        .vram_clk   (cpu_clk),
        .vram_waddr ({final_row[4:0], final_col[5:0]}),
        .vram_wdata (final_char_data[7:0]),
        .vram_we    (final_disp_wr_en)
    );


    ///////////////////////////////////////////////////////////////////
    // Memory / IO subsystem
    ///////////////////////////////////////////////////////////////////
    data_mem u_data_mem (
        .clk        (cpu_clk),          //< i
        .addr       (data_mem_addr),    //< i
        .rd_data    (m_rd_data),        //> o
        .wr_data    (m_wr_data),        //< i
        .wr         (m_wr),             //< i
        .rd         (m_rd)              //< i
    );

    //`define _BLINKY_ROM_
    `ifdef _BLINKY_ROM_
    rom_blinky_hello_world u_inst_mem (
        .addr       (i_addr),           //< i
        .data       (i_data)            //< io >
    );
    `else
    inst_mem u_inst_mem (
        .clk        (cpu_clk),          //< i
        .addr       (i_addr),           //< i
        .rd_data    (i_data),           //< io >
        .rd         (1'b1)              //< i
    );
    `endif


    ///////////////////////////////////////////////////////////////////
    // CPU instance
    ///////////////////////////////////////////////////////////////////
    noobs_cpu u_noobs_cpu (
        .clk        (cpu_clk),          //<i
        .reset_     (system_reset_),    //<i
        .i_data     (i_data),           //<i inst_mem_data
        .i_addr     (i_addr),           //>o inst_mem_address
        .m_wr_data  (m_wr_data),        //>o  data_mem_data wr_data
        .m_rd_data  (cpu_rd_data),      //<i  data_mem_data rd_data
        .m_addr     (m_addr),           //>o  data_mem_addr
        .m_rd       (m_rd),             //>o  data_mem_rd enable
        .m_wr       (m_wr),             //>o  data_mem_wr enable
        .m_en       (m_en)              //>   data_mem en
    );

endmodule
