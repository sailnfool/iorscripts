#!/bin/bash
########################################################################
# Author: Robert E. Novak
# email: novak5@llnl.gov, sailnfool@gmail.com
#
# Determine which benchmark data is stored in the current directory
# and find all of the data files and run them through extraction to
# create a CSV file which composites all of the benchmark runs.
########################################################################
dirname=$(pwd)
basedir=${dirname##*/}
isbatch=$(echo ${basedir} | sed -n "s/.*\(BATCH\).*/\1/p")
if [ ! "${isbatch}" = "BATCH" ]
then
	errecho "${0##*/}" ${LINENO} "Not a BATCH file. Quitting."
	exit 1
else
	benchtype=$(echo ${basedir} | sed -n "s/^.*BATCH-\([A-Z][A-Z]*\)-.*$/\1/p")
fi
case ${benchtype} in
	IOR)
		prefix="ior"
		extract="extract_ior"
		;;
	MD)
		prefix="MDTEST"
		extract="extract_md"
		;;
	\?)
		errecho "${0##*/}" ${LINENO} \
			"Unrecognized Benchmark. ${benchtype}"
		exit 1
		;;
esac
echo ${extract} $(find . -name "${prefix}*.txt" -print) | bash
