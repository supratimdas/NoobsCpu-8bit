#!/bin/bash
# File Name     : run_tests.sh
# Organization  : NONE
# Creation Date : 15-01-2021
# Last Modified : Monday 01 February 2021 08:03:21 PM IST
# Author        : Supratim Das (supratimofficio@gmail.com)
###########################################################

#################Description#####################
#
#
#
#
#
#
#################################################
make clean
TEST_DIR=`pwd`
PROJ_DIR=`pwd|sed 's/tests//g'`
echo $PROJ_DIR
CMODEL_DIR=`echo $PROJ_DIR`"cmodel/"
TB_DIR=`echo $PROJ_DIR`"tb/"
UTILS_DIR=`echo $PROJ_DIR`"utils/"

CMODEL=`echo $CMODEL_DIR`"noobsCpu"
VSIM=`echo $TB_DIR`"vsim.out"
ASSEMBLER=`echo $UTILS_DIR`"noobsASM.pl"

RED='\033[0;31m'
NC='\033[0m'
GREEN='\033[0;32m'
BOLD='\e[1m'
NORMAL='\e[0m'

echo -e "${BOLD}BUILDING CMODEL...${NORMAL}"
cd $CMODEL_DIR
make
echo -e "${BOLD}======================================================================= ${NORMAL}"

echo -e "${BOLD}BUILDING TB... ${NORMAL}"
cd $TB_DIR
make
echo -e "${BOLD}======================================================================= ${NORMAL}"

cd $TEST_DIR
echo "Running tests"

cat testlist | grep -v "\#" |
while read line
do
    testname=`echo $line| cut -d ',' -f 1`
    test_asm=`echo $line| cut -d ',' -f 2`
    test_desc=`echo $line| cut -d ',' -f 3`
    echo -e "${BOLD}=============Testname-"$testname"================-"$test_desc"-=====================${NORMAL}"
    rm *.txt
    rm *.vcd
    touch data_out_cmodel.txt
    touch data_out_vmodel.txt
    $ASSEMBLER $test_asm
    echo "running cmodel..."
    $CMODEL
    mv data_out.txt data_out_cmodel.txt
    echo "running vmodel..."
    $VSIM
    mv data_out.txt data_out_vmodel.txt
    dif=`diff data_out_cmodel.txt data_out_vmodel.txt | wc -l`
    if [[ $dif -eq 0 ]]
    then
        echo -e "${GREEN}========================================-"$testname"--PASS--========================================${NC}"
    else
        echo $dif" differences found between cmodel/vmodel final data_out dump"
        echo -e "${RED}========================================-"$testname"--FAIL--========================================${NC}"
    fi
done | grep "PASS\|FAIL"
