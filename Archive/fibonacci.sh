#!/bin/bash
################################################################################
# Author: Robert E. Novak
# email: novak5@llnl.gov, sailnfool@gmail.com
#
# generate a list of fibonacci numbers between low and high.  Don't assume that
# low is actually a fibonacci number.
#
################################################################################
low=$1
high=$2
fibonacci=1
previous=0
###################
# This initial sequence brings us up to the fibonacci number that is
# greated than or equal to low
###################
while [ ${fibonacci} -lt ${low} ]
do
	((newprevious = fibonacci))
	((fibonacci += previous ))
	((previous = newprevious))
done
while [ ${fibonacci} -lt ${high} ]
do
	sequence="${sequence} ${fibonacci}"
	((newprevious = fibonacci))
	((fibonacci += previous))
	((previous = newprevious))
done
echo ${sequence}
