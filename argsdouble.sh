#!/bin/bash
################################################################################
# Author: Robert E. Novak
# email: novak5@llnl.gov, sailnfool@gmail.com
#
# generate a list of numbers by multiplying by -e each time
# where 2 is the default
#
################################################################################
source func.errecho
USAGE="${0##*/} [-h] [-e #] <low #> <high #>\r\n
\t\tGenerate a list of numbers from low to high, exponentially increasing\r\n
\t\tby an exponent (Default 2)\r\n
\t-h\t\tPrint this message\r\n
\t-e\t#\tThe number to be used as exponent\r\n
"
exponent=2
optargs="he:"
while getopts ${optargs} name
do
	case ${name} in
		h)
			errecho "-e" ${USAGE}
			exit 0
			;;
		e)
			exponent=${OPTARG}
			;;
		\?)
			errecho "-e" ${LINENO} "invalid option: -${OPTARG}"
			errecho "-e" ${LINENO} ${USAGE}
			exit 1
			;;
	esac
done
shift $((OPTIND-1))
low=$1
high=$2
base=${low}
while [ ${base} -lt ${high} ]
do
	echo -n " ${base}"
	base=$(expr ${base} '*' ${exponent})
done
echo 
