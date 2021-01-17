#!/bin/bash
# File Name     : cleanall.sh
# Organization  : NONE
# Creation Date : 17-01-2021
# Last Modified : Sunday 17 January 2021 03:31:14 PM IST
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
cd cmodel && make clean && cd ..
cd vmodel && make clean && cd ..
cd tb && make clean && cd ..
cd tests && make clean && cd ..
