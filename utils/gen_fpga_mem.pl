#!/usr/bin/perl
use warnings;
use strict;
use Getopt::Long qw(GetOptions);

#########################NOTE#########################
#this utility is for reading output from assembler and
#generate inst_mem.v/data_mem.v for ice40 FPGA as of
#now it can generate memories upto 512B only, and 
#instances a single SB_RAM40_4K block ram.
######################################################

#######get args#############
my $input_file="code.txt";
my $mem_type="inst";
GetOptions('input_file=s' => \$input_file,
           'type=s' => \$mem_type
          ) or die "Usage: $0 -input_file FILENAME -type <inst|data>\n";

die "invalid option for -type arg. legal options are:\ninst\ndata\n" if(!($mem_type =~ /(inst|data)/));
###########################

my @vlog_out = "";

push(@vlog_out, << "VLOG_END");
 module ${mem_type}_mem (
    clk,    //< i
    addr,   //< i
    rd,     //< i
    rd_data,//> o
VLOG_END
if($mem_type =~ /data/) {
push(@vlog_out, << "VLOG_END");
    wr_data,    //< i
    wr,         //< i
VLOG_END
}
push(@vlog_out, << "VLOG_END");
 );

    //IOs
    input           clk;

    output [7:0]    rd_data;
    input [10:0]    addr;
    input           rd;
VLOG_END
if($mem_type =~ /data/) {
push(@vlog_out, << "VLOG_END");
    input           wr;
    input [7:0]     wr_data;
VLOG_END
}

push(@vlog_out, << "VLOG_END");

    SB_RAM40_4KNR #(
VLOG_END

open(INPUT_FILE, "<${input_file}") or die "Unable to open file ${input_file}, $!";

my $num_bytes = 0;
my $init_iterator = 0;
my @init_array = "";
while(<INPUT_FILE>) {
    my $line = $_;
    $line =~ s/\n//g;
    $line =~ s/0x//g;
    push(@init_array, "$line");
    push(@init_array, "00"); ##memory accesses are 16bits aligned, entering a dummy value
    $num_bytes+=2;
    if($num_bytes == 32) {
        @init_array = reverse(@init_array);
        my $initialization_str = join("_", @init_array);
        $initialization_str =~ s/_$//g;
push(@vlog_out, << "VLOG_END");
       .INIT_${init_iterator}(256'h$initialization_str),
VLOG_END
        $num_bytes = 0;
        $init_iterator++;
        @init_array = "";
    }
}
if($num_bytes < 32) {
    while($num_bytes < 32) {
        push(@init_array, "00");
        $num_bytes++; 
    }
    @init_array = reverse(@init_array);
    my $initialization_str = join("_", @init_array);
    $initialization_str =~ s/_$//g;
push(@vlog_out, << "VLOG_END");
       .INIT_${init_iterator}(256'h$initialization_str),
VLOG_END
    $init_iterator++;
}

if($mem_type eq "inst") {
push(@vlog_out, << "VLOG_END");
       .WRITE_MODE(0),
        .READ_MODE(1)
    ) ram40_4k_512x8 (
        .WADDR(),
        .WCLK(),
        .WCLKE(),
        .WDATA(),
        .WE(),
VLOG_END
}else{
push(@vlog_out, << "VLOG_END");
       .WRITE_MODE(1),
        .READ_MODE(1)
    ) ram40_4k_512x8 (
        .WADDR(addr),
        .WCLK(clk),
        .WCLKE(1'b1),
        .WDATA(wr_data),
        .WE(wr),
VLOG_END
}


push(@vlog_out, << "VLOG_END");
       .RDATA(rd_data),
        .RADDR(addr),
        .RCLKN(clk),
        .RCLKE(1'b1),
        .RE(rd),
    );
 endmodule
VLOG_END

if($mem_type eq "inst") {
    open(OUTPUT_FILE, ">inst_mem.v") or die "Unable to open file inst_mem.v $!";
    printf OUTPUT_FILE "@vlog_out";
}else{
    open(OUTPUT_FILE, ">data_mem.v") or die "Unable to open file data_mem.v $!";
    printf OUTPUT_FILE "@vlog_out";
}
close(OUTPUT_FILE);
close(INPUT_FILE);
