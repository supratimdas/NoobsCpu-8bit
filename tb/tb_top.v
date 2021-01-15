/*********************************************************** 
* File Name     : tb_top.v
* Organization  : NONE
* Creation Date : 02-01-2021
* Last Modified : Friday 15 January 2021 09:20:53 PM IST
* Author        : Supratim Das (supratimofficio@gmail.com)
************************************************************/ 

/*=============Description======================
 * basic verilog based testbench
 * - generates clocks/reset
 * - instances cpu_dut, and connects with imem/dmem
 * - reads assembled machine code, programs imem.dmem
 * - cpu processes data
 * - dumps out the final contents of dmem to a file
 * ============================================*/
`timescale 1ns/1ps

//include all RTL files
`include "asserts.v"
`include "ifetch.v"
`include "idecode.v"
`include "register_file.v"
`include "cpu_control.v"
`include "execute.v"
`include "noobs_cpu.v"

//inst/data memory model
`include "data_mem.v"


`define MAX_MEM_LIMIT 12'd2048

`define RESET_ASSERT_DURATION 50
`define SIM_DURATION 1000
`define DATA_MEM_INPUT_FILE "data.txt"
`define INST_MEM_INPUT_FILE "code.txt"
`define DATA_MEM_OUTPUT_FILE "data_out.txt"

module tb_top;
    reg clk;
    reg reset_;
    reg system_ready;
    reg data_memory_loaded;
    reg inst_memory_loaded;
    reg sim_done;


    integer cycle_count;
    integer data_mem_input_file;
    integer data_mem_output_file;
    integer inst_mem_input_file;

    integer i;

    initial begin
        $monitor("reset_ = %d", reset_);
        $monitor("cpu_reset_ = %d", cpu_reset_);
        //prepare for wave dump
        $dumpfile("test.vcd");
        $dumpvars(0, tb_top);
        //initialize clocks/reset_
        clk = 0;
        system_ready = 0;
        data_memory_loaded = 0;
        inst_memory_loaded = 0;
        reset_ = 1'bz;
        cycle_count = 0;
        sim_done = 0;

        //open data memory input File
        data_mem_input_file = $fopenr(`DATA_MEM_INPUT_FILE);
        if(data_mem_input_file == 0) begin
           $error("file %s not found", `DATA_MEM_INPUT_FILE); 
           $finish;
        end

        //open inst memory input File
        inst_mem_input_file = $fopenr(`INST_MEM_INPUT_FILE);
        if(inst_mem_input_file == 0) begin
           $error("file %s not found", `INST_MEM_INPUT_FILE); 
           $finish;
        end


        //test end
        wait(cycle_count == `SIM_DURATION);
        sim_done = 1;
        $display("***Test End after %d clock cycles***",cycle_count);


        //read final contents of data memory and dump to a file
        //open data memory output file for writing
        data_mem_output_file = $fopenw(`DATA_MEM_OUTPUT_FILE);
        if(data_mem_input_file == 0) begin
           $error("unable to create file: %s", `DATA_MEM_OUTPUT_FILE); 
           $finish;
        end

        wait(m_dump_addr == `MAX_MEM_LIMIT); 
        $display("data memory dumped in %s", `DATA_MEM_OUTPUT_FILE);

        //close file handles
        $fclose(data_mem_input_file);
        $fclose(inst_mem_input_file);
        $fclose(data_mem_output_file);
        $finish;
    end

    //clocks
    always begin
        #100
        $display("Starting Clocks\n");
        forever begin
            #50 clk = ~clk;
            if(clk == 1)
                cycle_count=cycle_count + 1;
        end
    end


    //reset_
    always begin
        #10 reset_ = (cycle_count >= `RESET_ASSERT_DURATION);
        system_ready = (reset_ && cycle_count > `RESET_ASSERT_DURATION);
    end


    reg [11:0] m_addr_in;
    reg [7:0]  m_data_in;
    reg        d_mem_prog_started;
    //program data_memory
    always @(posedge clk) begin
        if(!reset_) begin
            m_addr_in <= 11'd0;
            d_mem_prog_started <= 1'b0;
        end

        if(system_ready && !$feof(data_mem_input_file)) begin
            i=$fscanf(data_mem_input_file,"%x", m_data_in);
            $display("data_memory_programming_sequence: cycle = %d, addr = %x, data = %x", cycle_count, m_addr_in, m_data_in);
            data_memory_loaded <= 0;
            m_addr_in <= m_addr_in + d_mem_prog_started;
            d_mem_prog_started <= 1;
        end
        else if(system_ready && $feof(data_mem_input_file)) begin
            data_memory_loaded <= 1;
        end
    end

    reg [11:0] i_addr_in;
    reg [7:0]  i_data_in;
    reg        i_mem_prog_started;
    //program inst_memory
    always @(posedge clk) begin
        if(!reset_) begin
            i_addr_in <= 11'd0;
            i_mem_prog_started <= 1'b0;
        end

        if(system_ready && !$feof(inst_mem_input_file)) begin
            i=$fscanf(inst_mem_input_file,"%x", i_data_in);
            $display("inst_memory_programming_sequence: cycle = %d, addr = %x, data = %x", cycle_count, i_addr_in, i_data_in);
            inst_memory_loaded <= 0;
            i_addr_in <= i_addr_in + i_mem_prog_started;
            i_mem_prog_started <= 1'b1;
        end
        else if(system_ready && $feof(inst_mem_input_file)) begin
            inst_memory_loaded <= 1;
        end
    end


    //read data memory after simulation is done
    reg [11:0] m_dump_addr;
    reg [7:0] m_dump_data_no_x; //for filtering out x to 0
    always @(posedge clk) begin
        if(!reset_) begin
            m_dump_addr[11:0] <= 12'd8;
        end
        else begin
            if(m_dump_addr[11:0] <= `MAX_MEM_LIMIT) begin
                m_dump_addr[11:0] <= m_dump_addr + sim_done;
                //while dumping to output file, filter xs with 0s
                if(m_data === 8'bxxxx_xxxx) begin
                    m_dump_data_no_x = 8'd0;
                end
                else begin
                    m_dump_data_no_x = m_data;
                end
                $fdisplay(data_mem_output_file,"%02h",m_dump_data_no_x);
            end
        end
    end

    /********************************************************************************/

    //integration of memory with cpu

    wire [7:0]  m_data;
    wire [11:0] m_addr;
    wire        m_rd;
    wire        m_wr;
    wire        m_en;

    wire [7:0]  cpu_m_rd_data;
    wire [7:0]  cpu_m_wr_data;
    wire [11:0] cpu_m_addr;
    wire        cpu_m_rd;
    wire        cpu_m_wr;
    wire        cpu_m_en;


    assign m_data = data_memory_loaded ? (sim_done ? 8'bzzzz_zzzz : ((cpu_m_wr & cpu_m_en) ? cpu_m_wr_data : 8'bzzzz_zzzz)) : m_data_in;
    assign m_addr = data_memory_loaded ? (sim_done ? m_dump_addr : cpu_m_addr) : (m_addr_in + 8); //1st 8 addresses are special purpose 
    assign m_rd   = data_memory_loaded ? (sim_done ? 1'b1 : cpu_m_rd)   : 1'b0;
    assign m_wr   = data_memory_loaded ? (sim_done ? 1'b0 : cpu_m_wr)   : 1'b1;
    assign m_en   = data_memory_loaded ? (sim_done ? 1'b1 : cpu_m_en)   : 1'b1;  

    assign cpu_m_rd_data = m_data;


    wire [7:0]  i_data;
    wire [11:0] i_addr;
    wire        i_rd;
    wire        i_wr;
    wire        i_en;

    wire [7:0]  cpu_i_data;
    wire [11:0] cpu_i_addr;
    wire        cpu_i_rd;
    wire        cpu_i_wr;
    wire        cpu_i_en;

    assign i_data = inst_memory_loaded ? 8'bzzzz_zzzz : i_data_in;
    assign cpu_i_data = i_data;
    assign i_addr = inst_memory_loaded ? cpu_i_addr : i_addr_in; 
    assign i_rd   = inst_memory_loaded ? 1'b1   : 1'b0;
    assign i_wr   = inst_memory_loaded ? 1'b0   : 1'b1;
    assign i_en   = 1'b1;  

    wire programming_done;
    reg [5:0] cool_of_counter;
    wire cpu_reset_;
    assign programming_done = inst_memory_loaded & data_memory_loaded;

    always @(posedge clk) begin
        if(!reset_) begin
            cool_of_counter[5:0] <= 6'd0;
        end
        else begin
            if(cool_of_counter[5] == 0)
                cool_of_counter[5:0] <= cool_of_counter[5:0] + programming_done;
        end
    end

    assign cpu_reset_ = cool_of_counter[5];

    /****************system modules****************/
    wire dut_clk;
    assign dut_clk = clk & ~sim_done;

    //data memory instance

    data_mem u_data_mem (
                            .clk(dut_clk),
                            .data(m_data),
                            .addr(m_addr),
                            .rd(m_rd),
                            .wr(m_wr),
                            .en(m_en|system_ready)
                        );



    //program memory instance
    data_mem u_inst_mem (
                            .clk(dut_clk),
                            .data(i_data),
                            .addr(i_addr),
                            .rd(i_rd),
                            .wr(i_wr),
                            .en(i_en)
                        );


    //noobsCPU (actual DUT) instance
    noobs_cpu u_cpu_dut (
                            .clk(dut_clk),
                            .reset_(cpu_reset_),
                            .i_data(cpu_i_data),
                            .i_addr(cpu_i_addr),
                            .m_rd_data(cpu_m_rd_data),
                            .m_wr_data(cpu_m_wr_data),
                            .m_addr(cpu_m_addr),
                            .m_rd(cpu_m_rd),
                            .m_wr(cpu_m_wr),
                            .m_en(cpu_m_en)
                        );
endmodule
