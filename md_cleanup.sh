#!/bin/bash
########################################################################
# Author: Robert E. Novak
# email: novak5@llnl.gov, sailnfool@gmail.com
########################################################################
# The mdtest benchmark creates a set of files and directories beneath
# a directory on a parallel file system.
# The name of the filesystem is passed to this script as a parameter
# This application will lock and wait if there is another instance 
# running that is managing the top level directory used by mdtest
#
# Once we have a lock, then we will check all of the top level
# directory names that have been given to mdtest processes.  Each of
# the directories has a name of the form:
#
# /p/{filesystem}/${USER}/md.seq.$$
#
# we will collect a list of these directory names and reap the
# process ids from them.  Then we will see if the process (e.g. our
# parent) is still alive.  If there are no owners of this directory
# then we will begin a background process to count the number of files
# and directories left behind.  We will then remove those leftover
# files from a prior benchmark and collect a statistic on how long
# it takes to remove those directories.
# This process return after all of the background cleanup processes
# are created, but we won't wait for them to complete.
#
# The backgound processes will create a time stamped and process ID
# marked file in the same directory that will contain the cleanup
# information.
#
# Past experience has shown that depending on the file system this
# process can take as long as 24 hours so we don't want to wait for
# this.  If the sequence of benchmarks are able to create directory
# trees faster than these cleanup processes can run, that is a very
# bad sign.
########################################################################
source func.errecho
source func.insufficient
source func.global
source func.debug
USAGE="${0##*/} filesystem"
numparms=1
if [ "$#" -ne "${numparms}" ]
then
	errecho "${0##*/}" ${LINENO} \
		"${USAGE}"
	insufficient "${0##*/}" ${LINENO} "${numparms}"
	exit 1
fi
filesystem="$1"
whereami=$(pwd)
parentdirectory="${filesystem}/${USER}"
cd "${parentdirectory}"
dirlist="$(ls -d ${MD_DIR_PREFIX}.*)"
dircount="$(ls -d ${MD_DIR_PREFIX}.* | wc -l)"
rmcount=0
if [ "${dircount}" -gt "0" ]
then
	for onedir in ${dirlist}
	do
		ownerprocess=$(echo "${onedir}" | sed "s/^${MD_DIR_PREFIX}\.//")
		if [ $(ps -aux | grep -c "^${USER}[ ]*${ownerprocess}") -eq 0 ]
		then

			####################
			# There are no running owners of this directory, queue it for
			# removal
			####################
			echo "Launching md_count_and_remove ${filesystem} ${onedir}"
			md_count_and_remove ${filesystem} ${onedir} &
		fi
	done
fi
cd ${whereami}
exit 0
