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

ior_filesystemlistprefix=ior.filesystems
ior_runnerlistprefix=ior.runner
ior_processlistprefix=ior.processlist

ior_runnerlist="ior_runner -x mi25 -p10"
ior_runnerlistfile=""

ior_filesystemlist="/p/lustre3"
ior_filesystemlistfile=""

ior_processlist=10
ior_processlistfile=""

debug=0
DEBUGSETX=6
DEBUGNOEXECUTE=9

USAGE="${0##*/} [-[hv]] -r <list?.txt> -f <list?.txt> -p <list?.txt>\r\n
\t-h\t\tPrint this help information\r\n
\t-v\t\tTurn on verbose mode (works for -h: ${0##*/} -v -h)\r\n
\t-f\t<#>\tretrieves ${ior_filesystemlistprefix}.list<#>.txt for\r\n
\t\t\ta list of the filesystems that will be tested.  These should\r\n
\t\t\tall be mpi filesystems.\r\n
\t-r\t<#>\tretrieves ${ior_runnerlistprefix}.list<#>.txt for a\r\n
\t\t\tlist of the iorrunner commands (with options) that will\r\n
\t\t\tbe run as tests.\r\n
\t-p\t<#>\tretrieves ${ior_processlistprefix}.list<#>.txt for a\r\n
\t\t\tlist of the number of processes that will be requested\r\n
\t\t\twhen running iorrunner.  Note that number of processes\r\n
\t\t\tand -p <percentage> of nodes to processes.  Slightly\r\n
\t\t\tconfusing, see -vh\r\n"
VERBOSE_USAGE="${0##*/} Make sure you see ior_runner -h and -vh\r\n
\t\tThe set of all files for filesystems, ior_runner commands\r\n
\t\tand process lists are found by 'ls ior.\*.list\*.txt'\r\n
\t\tthis is highly useful if you want to perform\r\n
\t\tcomparison of lustre1 to lustre3 or any other\r\n
\t\tsets of filesystems.\r\n
\r\n
\t\tDefault runner list = ${ior_runnerlist}\r\n
\t\tDefault filesystem list = ${ior_filesystemlist}\r\n
\t\tDefault process list = ${ior_processlist}\r\n"

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
			ior_filesystemlistfile="${ior_filesystemlistprefix}.list${num}.txt"
			if [ ! -r ${ior_filesystemlistfile} ]
			then
				errecho ${0##*/} ${LINENO} "file ${ior_filesystemlistfile} not found"
				exit 1
			fi
			;;
		p)
			num=${OPTARG}
			ior_processlistfile="${ior_processlistprefix}.list${num}.txt"
			if [ ! -r ${ior_processlistfile} ]
			then
				errecho ${0##*/} ${LINENO} "file ${ior_processlistfile} not found"
				exit 1
			fi
			;;
		r)
			num=${OPTARG}
			ior_runnerlistfile="${ior_runnerlistprefix}.list${num}.txt"
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

mkdir -p ${IOR_TESTDIR} ${IOR_ETCDIR}

####################
# Create a lock file so that two different scripts don't update
# the test number
####################
echo $(func_getlock) | sed '/^$/d' >> ${LOCKERRS}

####################
# if it does not exist, initialize it with a zero value
####################

if [ ! -r ${IOR_BATCHNUMBERFILE} ]
then
	echo 0 > ${IOR_BATCHNUMBERFILE}
fi

####################
# retrieve the number in the file.
####################
iorbatchnumber=$(cat ${IOR_BATCHNUMBERFILE})

####################
# bump the test number and stuff it back in the file.
####################
((++iorbatchnumber))
echo ${iorbatchnumber} > ${IOR_BATCHNUMBERFILE}

echo $(func_releaselock) | sed '/^$/d' >> ${LOCKERRS}

####################
# retrieve the current batch number and stuff it in a test string for
# identifying the results directory
####################
iorbatchstring="${USER}-BATCH-IOR-$(printf '%04d' ${iorbatchnumber})"

export iorbatchstring

if [ ! -z "${ior_processlistfile}" ]
then
	ior_processlist=""
	for procnum in $(cat ${ior_processlistfile})
	do
		ior_processlist="${ior_processlist} ${procnum}"
	done
fi
if [ ! -z "${ior_filesystemlistfile}" ]
then
	ior_filesystemlist=""
	for filesystem in $(cat ${ior_filesystemlistfile})
	do
		ior_filesystemlist="${ior_filesystemlist} ${filesystem}"
	done
fi
if [ ! -z "${ior_runnerlistfile}" ]
then
	while read -r command
	do
		for filesystem in ${ior_filesystemlist}
		do
			echo "${command} -f ${filesystem} ${ior_processlist}"
			if [ $debug -lt ${DEBUGNOEXECUTE} ]
			then
				${command} -f ${filesystem} ${ior_processlist}
			fi
		done
	done < ${ior_runnerlistfile}
else
	command=${runnerlist}
	for filesystem in ${ior_filesystemlist}
	do
		echo "${command} -f ${filesystem} ${ior_processlist}"
		if [ $debug -lt ${DEBUGNOEXECUTE} ]
		then
			${command} -f ${filesystem} ${ior_processlist}
		fi
	done
fi
