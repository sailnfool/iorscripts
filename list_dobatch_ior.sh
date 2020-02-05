#!/bin/bash
########################################################################
# Author: Robert E. Novak
# email: novak5@llnl.gov, sailnfool@gmail.com
#
# Run ior based on lists of runs, lists of file systems and lists of
# processes provided as arguments.  E.G.
#
# dobatch_ior_list -f 1 -r 1 -p 1
########################################################################
source func.global
source func.errecho

iorfilesystemlistprefix=ior.filesystems
iorrunnerlistprefix=ior.runner
iorprocesslistprefix=ior

ior_runnerlist="ior_runner -x mi25 -p10"
ior_runnerlistfile=""

filesystemlist="/p/lustre3"
filesystemlistfile=""

processlist=10
processlistfile=""

debug=0
DEBUGSETX=6
DEBUGNOEXECUTE=9

USAGE="${0##*/} [-[hv]] -r <list?.txt> -f <list?.txt> -p <list?.txt>\r\n
\t-h\t\tPrint this help information\r\n
\t-v\t\tTurn on verbose mode (works for -h: ${0##*/} -v -h)\r\n
\t-f\t<#>\tretrieves ${iorfilesystemlistprefix}.list<#>.txt for\r\n
\t\t\ta list of the filesystems that will be tested.  These should\r\n
\t\t\tall be mpi filesystems.\r\n
\t-r\t<#>\tretrieves ${iorrunnerlistprefix}.list<#>.txt for a\r\n
\t\t\tlist of the iorrunner commands (with options) that will\r\n
\t\t\tbe run as tests.\r\n
\t-p\t<#>\tretrieves ${iorprocesslistprefix}.list<#>.txt for a\r\n
\t\t\tlist of the number of processes that will be requested\r\n
\t\t\twhen running iorrunner.  Note that number of processes\r\n
\t\t\tand -p <percentage> of nodes to processes.  Slightly\r\n
\t\t\tconfusing, see -vh\r\n"
VERBOSE_USAGE="${0##*/} Make sure you see iorunner -h and -vh\r\n
\t\tThe set of all files for filesystems, iorunner commands\r\n
\t\tand process lists are found by 'ls ior.\*.list\*.txt'\r\n
\t\tthis is highly useful if you want to perform\r\n
\t\tcomparison of lustre1 to lustre3 or any other\r\n
\t\tsets of filesystems.\r\n
\r\n
\t\tDefault runner list = ${ior_runnerlist}\r\n
\t\tDefault filesystem list = ${filesystemlist}\r\n
\t\tDefault process list = ${processlist}\r\n"

list_optionargs="hvr:f:p:d:"

while getopts ${list_optionargs} name
do
	case $name in
		d)
			FUNC_VERBOSE=1
			debug=${OPTARG}
			if [ $debug -eq ${DEBUGSETX} ]
			then
				set -x
			fi
			;;
		h)
			FUNC_VERBOSE=1
			echo -en ${USAGE}
			if [ "${runner_verbose}" = "TRUE" ]
			then
				echo -en ${VERBOSE_USAGE}
			fi
			exit 0
			;;
		f)
			num=${OPTARG}
			filesystemlistfile="${iorfilesystemlistprefix}.list${num}.txt"
			if [ ! -r ${filesystemlistfile} ]
			then
				errecho ${0##*/} ${LINENO} "file ${filesystemlistfile} not found"
				exit 1
			fi
			;;
		p)
			num=${OPTARG}
			processlistfile="${iorprocesslistprefix}.list${num}.txt"
			if [ ! -r ${processlistfile} ]
			then
				errecho ${0##*/} ${LINENO} "file ${processlistfile} not found"
				exit 1
			fi
			;;
		r)
			num=${OPTARG}
			ior_runnerlistfile="${iorrunnerlistprefix}.list${num}.txt"
			if [ ! -r ${ior_runnerlistfile} ]
			then
				errecho ${0##*/} ${LINENO} "file ${ior_runnerlistfile} not found"
				exit 1
			fi
			;;
		v)
			runner_verbose="TRUE"
			FUNC_VERBOSE=1
			;;
		\?)
			errecho "${0##*/}" ${LINENO} "Invalid option: -${OPTARG}"
			exit 1
			;;
	esac
done
shift $((OPTIND-1))

###################
# when we built ior, it was placed in a directory relative to the
# home directory.
####################
iorhomedir=$HOME/tasks/ior

####################
# the directory where binaries (bin) and libraries (lib) were placed
####################
iorinstalldir=${iorhomedir}/install.ior

####################
# where the ior bin (exec) file is found
####################
iorbindir=${iorinstalldir}/bin

####################
# we will place the testing directory at the same level as the installation
# directory, not as a subset of the installation.
####################
iortestdir=$(realpath ${iorinstalldir}/../testdir)
ioretcdir=${iortestdir}/etc

mkdir -p ${iortestdir} ${ioretcdir}

####################
# Create a lock file so that two different scripts don't update the test
# number
####################
while [ -f ${ioretcdir}/lock ]
do
	errecho ${LINENO} "Sleeping on lock acquistion for lock owned by"
	errecho ${LINENO} "$(ls -l ${ioretcdir}/lock*)"
	sleep 1
done
touch ${ioretcdir}/{lock,lock_process_${USER}_$$}

####################
# Use a file to keep track of the number of tests that have been run by this 
# script against the executable.
####################
iorbatchnumberfile=${ioretcdir}/IOR.BATCHNUMBER

####################
# if it does not exist, initialize it with a zero value
# otherwise retrieve the number in the file.
####################

if [ ! -f ${iorbatchnumberfile} ]
then
	iorbatchnumber=0
else
	iorbatchnumber=$(cat ${iorbatchnumberfile})
fi

####################
# bump the test number and stuff it back in the file.
####################
((++iorbatchnumber))
echo ${iorbatchnumber} > ${iorbatchnumberfile}

####################
# retrieve the current batch number and stuff it in a test string for
# identifying the results directory
####################
iorbatchstring="${USER}-BATCH-IOR-$(printf '%04d' ${iorbatchnumber})"

####################
# Now we can release the lock and the lock info
####################
rm -f ${ioretcdir}/{lock,lock_process_${USER}_$$}

export iorbatchstring

if [ ! -z "${processlistfile}" ]
then
	processlist=""
	for procnum in $(cat ${processlistfile})
	do
		processlist="${processlist} ${procnum}"
	done
fi
if [ ! -z "${filesystemlistfile}" ]
then
	filesystemlist=""
	for filesystem in $(cat ${filesystemlistfile})
	do
		filesystemlist="${filesystemlist} ${filesystem}"
	done
fi
if [ ! -z "${ior_runnerlistfile}" ]
then
	while read -r command
	do
		for filesystem in ${filesystemlist}
		do
			echo "${command} -f ${filesystem} ${processlist}"
			if [ $debug -lt ${DEBUGNOEXECUTE} ]
			then
				${command} -f ${filesystem} ${processlist}
			fi
		done
	done < ${ior_runnerlistfile}
else
	command=${runnerlist}
	for filesystem in ${filesystemlist}
	do
		echo "${command} -f ${filesystem} ${processlist}"
		if [ $debug -lt ${DEBUGNOEXECUTE} ]
		then
			${command} -f ${filesystem} ${processlist}
		fi
	done
fi
