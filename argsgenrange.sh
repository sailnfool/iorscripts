#!/bin/bash
################################################################################
# Author: Robert E. Novak
# email: novak5@llnl.gov, sailnfool@gmail.com
#
# generate a list of numbers between low and high
#
################################################################################
source func.genrange
$(func_genrange $1 $2)
