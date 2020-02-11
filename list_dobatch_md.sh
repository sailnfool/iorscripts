#!/bin/bash
########################################################################
# Author: Robert E. Novak
# email: novak5@llnl.gov, sailnfool@gmail.com
#
# Run a batch of mdtest benchmarks
#
########################################################################
source func.global
source func.errecho

md_filesystemlistprefix='md.filesystems*'
md_runnerlistprefix='md.runner*'
md_processlistprefix='md.processlist*'

md_runnerlist="md_runner -x mi25 -p10"
md_runnerlistfile=""

md_filesystemlist="/p/lustre3"
md_filesystemlistfile=""

md_processlist=10
md_processlistfile=""

debug=0
DEBUGSETX=6
DEBUGNOEXECUTE=9
USAGE="${0##*/} [-[hv]] -r <list?.txt> -f <list?.txt> -p <list?.txt>\r\n
\t-h\t\tPrint this help information\r\n
\t-v\t\tTurn on verbose mode (works for -h: ${0##*/} -v -h)\r\n
\t-f\t<#>\tretrieves ${md_filesystemlistprefix}.list<#>.txt for\r\n
\t\t\ta list of the filesystems that will be tested.  These should\r\n
\t\t\tall be mpi filesystems.\r\n
\t-r\t<#>\tretrieves ${md_runnerlistprefix}.list<#>.txt for a\r\n
\t\t\tlist of the iorrunner commands (with options) that will\r\n
\t\t\tbe run as tests.\r\n
\t-p\t<#>\tretrieves ${md_processlistprefix}.list<#>.txt for a\r\n
\t\t\tlist of the number of processes that will be requested\r\n
\t\t\twhen running iorrunner.  Note that number of processes\r\n
\t\t\tand -p <percentage> of nodes to processes.  Slightly\r\n
\t\t\tconfusing, see -vh\r\n"
VERBOSE_USAGE="${0##*/} Make sure you see md_runner -h and -vh\r\n
\t\tThe set of all files for filesystems, md_runner commands\r\n
\t\tand process lists are found by 'ls ior.\*.list\*.txt'\r\n
\t\tthis is highly useful if you want to perform\r\n
\t\tcomparison of lustre1 to lustre3 or any other\r\n
\t\tsets of filesystems.\r\n
\r\n
\t\tDefault runner list = ${md_runnerlist}\r\n
\t\tDefault filesystem list = ${md_filesystemlist}\r\n
\t\tDefault process list = ${md_processlist}\r\n"

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
			md_filesystemlistfile="${md_filesystemlistprefix}.list${num}.txt"
			if [ ! -r ${md_filesystemlistfile} ]
			then
				errecho ${0##*/} ${LINENO} "file ${md_filesystemlistfile} not found"
				exit 1
			fi
			;;
		p)
			num=${OPTARG}
			md_processlistfile="${md_processlistprefix}.list${num}.txt"
			if [ ! -r ${md_processlistfile} ]
			then
				errecho ${0##*/} ${LINENO} "file ${md_processlistfile} not found"
				exit 1
			fi
			;;
		r)
			num=${OPTARG}
			md_runnerlistfile="${md_runnerlistprefix}.list${num}.txt"
			if [ ! -r ${md_runnerlistfile} ]
			then
				errecho ${0##*/} ${LINENO} "file ${md_runnerlistfile} not found"
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

mkdir -p ${TESTDIR} ${ETCDIR}

####################
# Create a lock file so that two different scripts don't update the test
# number
####################
echo $(func_getlock) | sed '/^$/d' >> ${LOCKERRS}

####################
# if it does not exist, initialize it with a zero value
####################

if [ ! -r ${BATCHNUMBERFILE} ]
then
	echo 0 > ${BATCHNUMBERFILE}
fi

####################
# retrieve the number in the file.
####################
iorbatchnumber=$(cat ${BATCHNUMBERFILE})

####################
# bump the test number and stuff it back in the file.
####################
((++iorbatchnumber))
echo ${iorbatchnumber} > ${BATCHNUMBERFILE}

####################
# Now we can release the lock 
####################
echo $(func_releaselock) | sed '/^$/d' >> ${LOCKERRS}

####################
# retrieve the current test number and stuff it in a test string for
# identifying the results directory
####################
mdbatchstring="${USER}-BATCH-MD-$(printf '%04d' ${iorbatchnumber})"

export mdbatchstring


if [ ! -z "${md_processlistfile}" ]
then
	md_processlist=""
	for procnum in $(cat ${md_processlistfile})
	do
		md_processlist="${md_processlist} ${procnum}"
	done
fi
if [ ! -z "${md_filesystemlistfile}" ]
then
	md_filesystemlist=""
	for filesystem in $(cat ${md_filesystemlistfile})
	do
		md_filesystemlist="${md_filesystemlist} ${filesystem}"
	done
fi
if [ ! -z "${md_runnerlistfile}" ]
then
	while read -r command
	do
		for filesystem in ${md_filesystemlist}
		do
			echo "${command} -f ${filesystem} ${md_processlist}"
			if [ $debug -lt ${DEBUGNOEXECUTE} ]
			then
				${command} -f ${filesystem} ${md_processlist}
			fi
		done
	done < ${md_runnerlistfile}
else
	command=${runnerlist}
	for filesystem in ${md_filesystemlist}
	do
		echo "${command} -f ${filesystem} ${md_processlist}"
		if [ $debug -lt ${DEBUGNOEXECUTE} ]
		then
			${command} -f ${filesystem} ${md_processlist}
		fi
	done
fi
