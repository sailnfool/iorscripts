#!/bin/bash
################################################################################
# Author: Robert E. Novak
# email: novak5@llnl.gov, sailnfool@gmail.com
#
# generate a list of fibonacci numbers between low and high.  Don't assume that
# low is actually a fibonacci number.
#
################################################################################
source func.errecho
USAGE="${0##*/} [-h] <low #> <high #>\r\n
\t\tgenerate a sequence of fibonacci numbers between low and high\r\n
\t\tthis does not assume that low # is a fibonacci number and generates\r\n
\t\tthe lowest fibonacci number that is greater than or equal to low.\r\n
"
low=$1
high=$2
fibonacci=1
previous=0
optargs="h"

while getopts ${optargs} name
do
	case ${name} in
		h)
			errecho "-e" ${USAGE}
			exit 0
			;;
		\?)
			errecho "-e" ${LINENO} "invalid option: -${OPTARG}"
			errecho "-e" ${USAGE}
			exit 1
			;;
	esac
done
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
