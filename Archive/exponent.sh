#!/bin/bash
################################################################################
# Author: Robert E. Novak
# email: novak5@llnl.gov, sailnfool@gmail.com
#
# generate a list of exponentially ^2 number of processes from low to high
#
################################################################################
low=$1
high=$2
exponent=${low}
sequence="${low}"
while [ ${exponent} -lt ${high} ]
do
	echo -n " ${exponent}"
	exponent=`expr ${exponent} '*' 2`
done
echo 
