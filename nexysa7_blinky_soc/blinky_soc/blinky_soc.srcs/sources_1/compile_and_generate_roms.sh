if [[ $1 == "" ]]
then
    echo "Usage : ./compile_and_generate_roms.sh <asm_file>"
    exit
fi
../../../../utils/noobsASM.pl $1
../../../../utils/gen_fpga_mem.pl -input_file code.txt -type inst -target XILINX
../../../../utils/gen_fpga_mem.pl -input_file data.txt -type data -target XILINX
rm *.txt
