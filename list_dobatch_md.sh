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

####################
# Define a path to the local set of files that define the parameters
# for running the benchmarks.  The files are organized into four
# groups:
#
# f - files containing the list of file systems to be tested
# p - files containing the list of number of processes to be tested
# r - files containing the command line for the *_runner script,
#     less option lists
# o - the files containing the list of options for controlling the
#     benchmarks
#
# The form of the files are syntactically:
#
# ior.x.[0-9]+*.txt
# 
# The intent is that after the prefix we have a descriptive name for
# the content of the controlling files.
####################
localetc=${HOME}/tasks/scripts/etc

####################
# Define the four file prefixes
####################
md_filesyslistprefix='${localetc}/md.f.'
md_runnerlistprefix='${localetc}/md.r.'
md_opt_prefix='${localetc}/md.o.'
md_processlistprefix='${localetc}/md.p.'

####################
# define the default command and clear the file name
####################
md_runnerlist="md_runner -x mi25 -p10"
md_runnerlistfile=""

####################
# define the default file system and clear the file name
####################
md_filesystemlist="/p/lustre3"
md_filesystemlistfile=""

####################
# define the default list of processes and clear the file name
####################
md_processlist=10
md_processlistfile=""

####################
# define the default options and clear the file name
####################
md_optionlist="-i 5"
md_optionlistfile=""

####################
# set the debug level to zero
# Define the debug levels:
#
# DEBUGSETX - turn on set -x to debug
# DEBUGNOEXECUTE - generate and display the command lines but don't
#                  execute the benchmark
####################
debug=0
DEBUGSETX=6
DEBUGNOEXECUTE=9

####################
# Define the usage and Verbose usage
####################
USAGE="${0##*/} [-[hv]] -r <list?.txt> -f <list?.txt> -p <list?.txt>\r\n
\t-h\t\tPrint this help information\r\n
\t-v\t\tTurn on verbose mode (works for -h: ${0##*/} -v -h)\r\n
\t-f\t<#>\tretrieves ${md_filesyslistprefix}<#>....txt for\r\n
\t\t\ta list of the filesystems that will be tested.  These should\r\n
\t\t\tall be mpi filesystems.\r\n
\t-r\t<#>\tretrieves ${md_runnerlistprefix}<#>....txt for a\r\n
\t\t\tlist of the iorrunner commands (with options) that will\r\n
\t\t\tbe run as tests.\r\n
\t-o\t<#>\tretrieves ${md_opt_prefix}<#>....txt for the\r\n
\t\t\toptions sent to mdtest due to a problem of putting them\r\n
\t\t\tinto runner\r\n
\t-p\t<#>\tretrieves ${md_processlistprefix}<#>i....txt for a\r\n
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
\t\tDefault process list = ${md_processlist}\r\n
\t\tdefault option list = ${md_optionlist}\r\n"

list_optionargs="hvr:f:p:d:o:"

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
			md_filesystemlistfile="${md_filesyslistprefix}${num}*.txt"
			if [ $(ls ${md_filesystemlistfile} | wc -l) -gt 1 ]
			then
				FUNC_VERBOSE=1
				errecho ${0##*/} ${LINENO} "-f ${num} is not unique"
				ls -l ${md_filesystemlistfile}
				exit 1
			fi
			if [ ! -r ${md_filesystemlistfile} ]
			then
				FUNC_VERBOSE=1
				errecho ${0##*/} ${LINENO} "file ${md_filesystemlistfile} not found"
				exit 1
			fi
			;;
		o)
			num=${OPTARG}
			md_optionlistfile="${md_opt_prefix}${num}*.txt"
			if [ $(ls ${md_optionlistfile} | wc -l) -gt 1 ]
			then
				FUNC_VERBOSE=1
				errecho ${0##*/} ${LINENO} "-o ${num} is not unique"
				ls -l ${md_optionlistfile}
				exit 1
			fi
			if [ ! -r ${md_optionlistfile} ]
			then
				FUNC_VERBOSE=1
				errecho ${0##*/} ${LINENO} "file ${md_optionlistfile} not found"
				exit 1
			fi
			;;
		p)
			num=${OPTARG}
			md_processlistfile="${md_processlistprefix}${num}*.txt"
			if [ $(ls ${md_processlistfile} | wc -l) -gt 1 ]
			then
				FUNC_VERBOSE=1
				errecho ${0##*/} ${LINENO} "-p ${num} is not unique"
				ls -l ${md_processlistfile}
				exit 1
			fi
			if [ ! -r ${md_processlistfile} ]
			then
				FUNC_VERBOSE=1
				errecho ${0##*/} ${LINENO} "file ${md_processlistfile} not found"
				exit 1
			fi
			;;
		r)
			num=${OPTARG}
			md_runnerlistfile="${md_runnerlistprefix}${num}*.txt"
			if [ $(ls ${md_runnerlistfile} | wc -l) -gt 1 ]
			then
				FUNC_VERBOSE=1
				errecho ${0##*/} ${LINENO} "-r ${num} is not unique"
				ls -l ${md_runnerlistfile}
				exit 1
			fi
			if [ ! -r ${md_runnerlistfile} ]
			then
				FUNC_VERBOSE=1
				errecho ${0##*/} ${LINENO} "file ${md_runnerlistfile} not found"
				exit 1
			fi
			;;
		v)
			runner_verbose="TRUE"
			FUNC_VERBOSE=1
			;;
		\?)
			FUNC_VERBOSE=1
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
# retrieve the current batch number and stuff it in a test string for
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
			if [ ! -z ${md_optionlistfile} ]
			then
				while read -r options
				do
					echo "${command} -f ${filesystem} -o \"${options}\" ${md_processlist}"
					if [ $debug -lt ${DEBUGNOEXECUTE} ]
					then
						${command} -f ${filesystem} -o "${options}" ${md_processlist}
					fi
				done < ${md_optionlistfile}
			else
				echo "${command} -f ${filesystem} -o \"${md_optionlist}\" ${md_processlist}"
				if [ $debug -lt ${DEBUGNOEXECUTE} ]
				then
					${command} -f ${filesystem} -o "${md_optionlist}" ${md_processlist}
				fi
			fi
		done
	done < ${md_runnerlistfile}
else
	command=${runnerlist}
	for filesystem in ${md_filesystemlist}
	do
		if [ ! -z ${md_optionlistfile} ]
		then
			while read -r options
			do
				echo "${command} -f ${filesystem} -o \"${options}\" ${md_processlist}"
				if [ $debug -lt ${DEBUGNOEXECUTE} ]
				then
					${command} -f ${filesystem} -o "${options}" ${md_processlist}
				fi
			done < ${md_optionlistfile}
		else
			echo "${command} -f ${filesystem} -o \"${md_optionlist}\" ${md_processlist}"
			if [ $debug -lt ${DEBUGNOEXECUTE} ]
			then
				${command} -f ${filesystem} -o "${md_optionlist}" ${md_processlist}
			fi
		fi
	done
fi
