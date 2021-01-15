#!/bin/bash
# File Name     : run_tests.sh
# Organization  : NONE
# Creation Date : 15-01-2021
# Last Modified : Friday 15 January 2021 08:48:03 PM IST
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
TEST_DIR=`pwd`
PROJ_DIR=`pwd|sed 's/tests//g'`
echo $PROJ_DIR
CMODEL_DIR=`echo $PROJ_DIR`"cmodel/"
TB_DIR=`echo $PROJ_DIR`"tb/"
UTILS_DIR=`echo $PROJ_DIR`"utils/"

CMODEL=`echo $CMODEL_DIR`"noobsCpu"
VSIM=`echo $TB_DIR`"vsim.out"
ASSEMBLER=`echo $UTILS_DIR`"noobsASM.pl"

echo "BUILDING CMODEL..."
cd $CMODEL_DIR
make clean
make
echo "======================================================================="

echo "BUILDING TB..."
cd $TB_DIR
make clean
make
echo "======================================================================="

cd $TEST_DIR
echo "Running tests"

cat testlist | grep -v "\#" |
while read line
do
    testname=`echo $line| cut -d ',' -f 1`
    test_asm=`echo $line| cut -d ',' -f 2`
    test_desc=`echo $line| cut -d ',' -f 3`
    echo "=============Testname-"$testname"================-"$test_desc"-====================="
    $ASSEMBLER $test_asm
    $CMODEL
    mv data_out.txt data_out_cmodel.txt
    ls
    $VSIM
    mv data_out.txt data_out_vmodel.txt
    ls
done
