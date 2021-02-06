#!/usr/bin/perl
use warnings;
use strict;
use Getopt::Long qw(GetOptions);

#a very basic lookup table based assembler
my %OP_CODE_HASH;
$OP_CODE_HASH{NOP}          = 0b000_00_000;
$OP_CODE_HASH{RET}          = 0b000_00_001;
$OP_CODE_HASH{HALT}         = 0b000_00_010;
$OP_CODE_HASH{SET_BCZ}      = 0b000_00_011;
$OP_CODE_HASH{SET_BCNZ}     = 0b000_00_100;
$OP_CODE_HASH{CLR_BC}       = 0b000_00_101;
$OP_CODE_HASH{SET_ADR_MODE} = 0b000_00_110;
$OP_CODE_HASH{RST_ADR_MODE} = 0b000_00_111;
$OP_CODE_HASH{CALL}     = 0b000_11_000;
#$OP_CODE_HASH{CALLZ}    = 0b000_11_000;
#$OP_CODE_HASH{CALLNZ}   = 0b000_11_000;
$OP_CODE_HASH{JMP}      = 0b000_10_000;
$OP_CODE_HASH{JMPZ}     = 0b000_10_000;
$OP_CODE_HASH{JMPNZ}    = 0b000_10_000;
$OP_CODE_HASH{ADD}      = 0b001_0_00_00;
$OP_CODE_HASH{ADDI}     = 0b001_1_00_00;
$OP_CODE_HASH{SUB}      = 0b010_0_00_00;
$OP_CODE_HASH{SUBI}     = 0b010_1_00_00;
$OP_CODE_HASH{AND}      = 0b011_0_00_00;
$OP_CODE_HASH{ANDI}     = 0b011_1_00_00;
$OP_CODE_HASH{OR}       = 0b100_0_00_00;
$OP_CODE_HASH{ORI}      = 0b100_1_00_00;
$OP_CODE_HASH{XOR}      = 0b101_0_00_00;
$OP_CODE_HASH{XORI}     = 0b101_1_00_00;
$OP_CODE_HASH{LOAD}     = 0b110_00_000;
$OP_CODE_HASH{STORE}    = 0b111_00_000;

my %REGISTER_HASH;
$REGISTER_HASH{R0}      = 0;
$REGISTER_HASH{R1}      = 1;
$REGISTER_HASH{R2}      = 2;
$REGISTER_HASH{R3}      = 3;

my %SYMBOL_TABLE;

my $last_branch_condition = 0;   #0=unconditional branch, 1=branch if zero, 2=branch if not zero
my $data_section = 0;
my $code_section = 0;

my @data_mem;
my @code_mem;
my $data_index = 0;
my $code_index = 0;

my $inp_asm_file = "test.asm";
my $args = $#ARGV + 1;

if(($#ARGV + 1) == 1) {
    $inp_asm_file = $ARGV[0];
}
###########PASS-1: resolve labels/addresses#####################
open(ASM, "<${inp_asm_file}") or die "Unable to open file ${inp_asm_file}, $!";

$data_index = 0;
$code_index = 0;

my $line_num = 0;
while (<ASM>) {
    my $line = $_;
    $line =~ s/\n//g;   #remove newline
    $line =~ s/^\s+//g; #remove leading whitespace
    $line =~ s/\s+/ /g; #replace multi-whitespace with single whitespace
    $line =~ s/, /,/g; #replace whitespaces after comma (generally indicates args in assembly)
    $line_num += 1;
    my $num_ws = () = $line =~ /\s/gi;
    if($line =~ /:/) { ## indicates that it has a label
        $num_ws=$num_ws-1;
    }
    if($num_ws == 2) {
        die "unwanted whitespace in : ${inp_asm_file}:${line_num} ==>$line\n";
    }
    if($line =~ /data/) {       #entry to data section
        $data_section = 1;
        $code_section = 0;
    }elsif($line =~ /code/) {   #entry to code section
        $data_section = 0;
        $code_section = 1;
    }else{                      #actual data/code 
        if($data_section){
            #check if there is any label associated and add it to the hash
            if($line eq "") {
                next;
            }
            if($line =~ /:/) {  #found a data label
                my @label_args = split(':',$line);
                if(($label_args[0] =~ /^\d.*/)) {
                    die "ERROR: ILLEGAL_ID_NAME: $label_args[0] \nIdentifiers should never start with a number\n";
                }
                 
                if(not defined($SYMBOL_TABLE{$label_args[0]})){
                    $SYMBOL_TABLE{$label_args[0]} = $data_index + 8;
                }else{
                    die "ERROR: Identifier $label_args[0] redefined\n";
                }
                my @num_args = split(',',$label_args[1]);
                $data_index += @num_args-1;
            }
            $data_index++;
        }

        if($code_section){
            if($line eq "") {
                next;
            }
            if($line =~ /:/) {  #found a data label
                my @label_args = split(':',$line);
                if(not defined($SYMBOL_TABLE{$label_args[0]})){
                    $SYMBOL_TABLE{$label_args[0]} = $code_index;
                }else{
                    die "Identifier: $label_args[0] redefined\n";
                }
                $line = $label_args[1];
            }

            my @inst_token = split(' ',$line);
            my $OPCODE = $inst_token[0];
            my $ARGS = defined($inst_token[1]) ? $inst_token[1] : "";
            my @ARGLIST = split(',',$ARGS);
            my $num_args = @ARGLIST;
            if($OPCODE =~ /I$/) {   #immediate op
                $code_index++;
                $code_index++;
            }elsif($OPCODE =~ /(JMP|CALL|LOAD|STORE)/) {    #address based ops also immediate
                if($OPCODE =~ /(JMPZ|CALLZ)/) {
                    if($last_branch_condition!=1) {
                        $code_index++;
                        $last_branch_condition = 1;
                    }
                }elsif($OPCODE =~ /(JMPNZ|CALLNZ)/){
                    if($last_branch_condition!=2) {
                        $code_index++;
                        $last_branch_condition = 2;
                    }
                }

                $code_index++;
                $code_index++;
            }else{  #opcodes without any args
                $code_index++;
            }
        }
    }
}

close(ASM);


###############PASS-2 machine code translation################
open(ASM, "<${inp_asm_file}") or die "Unable to open file ${inp_asm_file}, $!";

$data_index = 0;
$code_index = 0;
$last_branch_condition = 0;

while (<ASM>) {
    my $line = $_;
    $line =~ s/\n//g;   #remove newline
    $line =~ s/^\s+//g; #remove leading whitespace
    $line =~ s/\s+/ /g; #replace multi-whitespace with single whitespace
    $line =~ s/, /,/g; #replace whitespaces after comma (generally indicates args in assembly)
    
    if($line eq "") { #skip empty lines
        next;
    }
    #if line has a label, strip the label
    if($line =~ /:/) {  #found a label
        my @label_args = split(':',$line);
        $line = $label_args[1];
    }

    if($line =~ /data/) {       #entry to data section
        $data_section = 1;
        $code_section = 0;
    }elsif($line =~ /code/) {   #entry to code section
        $data_section = 0;
        $code_section = 1;
    }else{                      #actual data/code 
        if($data_section){
            my @elements = split(',', $line);
            foreach my $data_elem (@elements) {
                $data_mem[$data_index] = to_int($data_elem);
                $data_index++;
            }
        }

        if($code_section){
            my @inst_token = split(' ',$line);
            my $OPCODE = $inst_token[0];
            my $ARGS = defined($inst_token[1]) ? $inst_token[1] : "";
            my @ARGLIST = split(',',$ARGS);
            my $num_args = @ARGLIST;
            if(not defined($OP_CODE_HASH{$OPCODE})) {
                die "ERROR: Undefined OPCODE ${OPCODE}\n";
            }
            if($OPCODE =~ /I$/) {   #immediate op
                my $dst_reg = to_int($REGISTER_HASH{$ARGLIST[0]}) << 2;
                my $src_reg = to_int($REGISTER_HASH{$ARGLIST[1]});
                $code_mem[$code_index++] = $OP_CODE_HASH{$OPCODE} | $dst_reg | $src_reg;
                $code_mem[$code_index++] = to_int($ARGLIST[2]);
            }elsif($OPCODE =~ /(JMP|CALL|LOAD|STORE)/) {    #address based ops also immediate
                if($OPCODE =~ /JMPZ/) {
                    if($last_branch_condition!=1) {
                        $code_mem[$code_index++] = $OP_CODE_HASH{SET_BCZ};
                        $last_branch_condition = 1;
                    }
                }elsif($OPCODE =~ /JMPNZ/){
                    if($last_branch_condition!=2) {
                        $code_mem[$code_index++] = $OP_CODE_HASH{SET_BCNZ};
                        $last_branch_condition = 2;
                    }
                }elsif($OPCODE =~ /JMP/) {
                    if($last_branch_condition!=0) {
                        $code_mem[$code_index++] = $OP_CODE_HASH{CLR_BC};
                        $last_branch_condition = 0;
                    }
                }
                my $address = 0;
                my $dst_reg = 0;
                if($OPCODE =~ /(JMP|CALL)/) {
                    $address = ($ARGLIST[0]  =~ /^\d.*/) ?to_int($ARGLIST[0]) : (defined($SYMBOL_TABLE{$ARGLIST[0]}) ? $SYMBOL_TABLE{$ARGLIST[0]} : die("ERROR: Undefined Identifier $ARGLIST[0]"));
                }else{ #load/store
                    $dst_reg = (to_int($REGISTER_HASH{$ARGLIST[0]}) << 3);
                    $address = ($ARGLIST[1]  =~ /^\d.*/) ?to_int($ARGLIST[1]) : (defined($SYMBOL_TABLE{$ARGLIST[1]}) ? $SYMBOL_TABLE{$ARGLIST[1]} : die("ERROR: Undefined Identifier $ARGLIST[1]"));
                }
                my $address_msb = ($address >> 8) & 0x07;
                my $address_lsb = $address & 0x00ff;
                $code_mem[$code_index++] = $OP_CODE_HASH{$OPCODE}|$dst_reg|$address_msb;
                $code_mem[$code_index++] = $address_lsb;
            }elsif($num_args > 1) {
                my $src_reg0 = to_int($REGISTER_HASH{$ARGLIST[0]}) << 2;
                my $src_reg1 = to_int($REGISTER_HASH{$ARGLIST[1]});
                $code_mem[$code_index++] = $OP_CODE_HASH{$OPCODE} | $src_reg1 | $src_reg0;
            }else{  #opcodes without any args
                $code_mem[$code_index++] = $OP_CODE_HASH{$OPCODE};
            }
        }
    }
}

close(ASM);


open(DATA, ">data.txt") or die "Unable to open file data.txt, $!";
open(CODE, ">code.txt") or die "Unable to open file code.txt, $!";

foreach my $data (@data_mem) {
    printf DATA "0x%02x\n", $data;
}
close(DATA);

foreach my $code (@code_mem) {
    printf CODE "0x%02x\n", $code;
}
close(CODE);

sub to_int {
    my $num = shift;
    $num =~ s/ //g; #remove any unwanted whitespaces
    $num = oct($num) if $num =~ /^0/;
    return $num;
}
