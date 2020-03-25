#!/bin/bash
########################################################################
# Author: Robert E. Novak
# email: novak5@llnl.gov, sailnfool@gmail.com
########################################################################
# Remove a directory tree from a filesystem.
# Take a count of the files and directories in the tree before
# removing.
########################################################################
source func.errecho
source func.insufficient
source func.global
source func.debug

USAGE="${0##*/} filesystem directory"
starttime=$(date "+%Y%m%d_%H%M%S")
numparms=2
if [ "$#" -ne "${numparms}" ]
then
	errecho "${0##*/}" ${LINENO} "${USAGE}"
	insufficient "${0##*/}" ${LINENO} "${numparms}"
fi
filesystem=$1
directory=$2
filename="Removal_${dirname}_${starttime}"
parentdirectory="${filesystem}/${USER}"
cd "${parentdirectory}"
echo "Directory count $(find ${directory} -type d -print | wc -l)" > \
	${filename}
echo "File count $(find ${directory} -type d -print | wc -l)" >> \
	${filename}
/usr/bin/time rm -rf ${directory} 2>&1 | tee -a ${filename}
exit 0
