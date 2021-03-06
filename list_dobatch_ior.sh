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
source func.debug

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
ior_filesystemlistprefix="${localetc}/ior.f."
ior_runnerlistprefix="${localetc}/ior.r."
ior_processlistprefix="${localetc}/ior.p."
ior_opt_prefix="${localetc}/ior.o."

####################
# define the default command and clear the file name
####################
ior_runnerlist="ior_runner -x mi25 -p10"
ior_runnerlistfile=""

####################
# define the default file system and clear the file name
####################
ior_filesystemlist="/p/lustre3"
ior_filesystemlistfile=""

####################
# define the default list of processes and clear the file name
####################
ior_processlist=10
ior_processlistfile=""

####################
# define the default options and clear the file name
####################
ior_optionlist="-i 5"
ior_optionlistfile=""

####################
# set the debug level to DEBUGOFF
####################
debug=${DEBUGOFF}

####################
# Define the usage and Verbose usage
####################
USAGE="${0##*/} [-[hv]] -r <list?.txt> -f <list?.txt> -p <list?.txt>\r\n
\t-h\t\tPrint this help information\r\n
\t-v\t\tTurn on verbose mode (works for -h: ${0##*/} -v -h)\r\n
\t-f\t<#>\tretrieves ${ior_filesystemlistprefix}<#>...txt for\r\n
\t\t\ta list of the filesystems that will be tested.  These should\r\n
\t\t\tall be mpi filesystems.\r\n
\t-r\t<#>\tretrieves ${ior_runnerlistprefix}<#>...txt for a\r\n
\t\t\tlist of the iorrunner commands (with options) that will\r\n
\t\t\tbe run as tests.\r\n
\t-o\t<#>\tretrieves ${ior_opt_prefix}<#>...txt for the\r\n
\t\t\toptions sent to ior due to a problem of passing quoted\r\n
\t\t\tparameter lists two levels in bash\r\n
\t-p\t<#>\tretrieves ${ior_processlistprefix}<#>...txt for a\r\n
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
\t\tDefault process list = ${ior_processlist}\r\n
\t\tDefault option list = ${ior_optionlist}\r\n"

list_optionargs="hvd:f:o:p:r:"

filestring=0
optstring=0
procstring=0
runstring=0
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
			ior_filesystemlistfile="${ior_filesystemlistprefix}${num}*.txt"
			if [ $(ls ${ior_filesystemlistfile} | wc -l) -gt 1 ]
			then
				FUNC_VERBOSE=1
				errecho ${0##*/} ${LINENO} "-f ${num} is not unique"
				ls -l ${ior_filesystemlistfile}
				exit 1
			fi
			if [ ! -r ${ior_filesystemlistfile} ]
			then
				FUNC_VERBOSE=1
				errecho ${0##*/} ${LINENO} "file ${ior_filesystemlistfile} not found"
				exit 1
			fi
			filestring=${num}
			;;
		o)
			num=${OPTARG}
			ior_optionlistfile="${ior_opt_prefix}${num}*.txt"
			if [ $(ls ${ior_optionlistfile} | wc -l) -gt 1 ]
			then
				FUNC_VERBOSE=1
				errecho ${0##*/} ${LINENO} "-f ${num} is not unique"
				ls -l ${ior_optionlistfile}
				exit 1
			fi
			if [ ! -r ${ior_optionlistfile} ]
			then
				FUNC_VERBOSE=1
				errecho ${0##*/} ${LINENO} "file ${ior_optionlistfile} not found"
				exit 1
			fi
			optstring=${num}
			;;
		p)
			num=${OPTARG}
			ior_processlistfile="${ior_processlistprefix}${num}*.txt"
			if [ $(ls ${ior_processlistfile} | wc -l) -gt 1 ]
			then
				FUNC_VERBOSE=1
				errecho ${0##*/} ${LINENO} "-f ${num} is not unique"
				ls -l ${ior_processlistfile}
				exit 1
			else
				processlistfile=${ior_processlistfile}
			fi
			if [ ! -r ${processlistfile} ]
			then
				FUNC_VERBOSE=1
				errecho ${0##*/} ${LINENO} "file ${processlistfile} not found"
				exit 1
			fi
			procstring=${num}
			;;
		r)
			num=${OPTARG}
			ior_runnerlistfile="${ior_runnerlistprefix}${num}*.txt"
			if [ $(ls ${ior_runnerlistfile} | wc -l) -gt 1 ]
			then
				FUNC_VERBOSE=1
				errecho ${0##*/} ${LINENO} "-f ${num} is not unique"
				ls -l ${ior_runnerlistfile}
				exit 1
			fi
			if [ ! -r ${ior_runnerlistfile} ]
			then
				FUNC_VERBOSE=1
				errecho ${0##*/} ${LINENO} "file ${ior_runnerlistfile} not found"
				exit 1
			fi
			runstring=${num}
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
batchnumber=$(func_getbatchnumber)

####################
# retrieve the current batch number and stuff it in a test string for
# identifying the results directory
####################
batchstring="${USER}-BATCH-IOR-$(printf '%04d' ${batchnumber})"
batchstring="${batchstring}_f${filestring}o${optstring}p${procstring}r${runstring}"
export batchstring
batchdir=${TESTDIR}/${batchstring}
mkdir -p ${batchdir}

if [ ! -z "${processlistfile}" ]
then
	ior_processlist=""
	for procnum in $(cat ${processlistfile})
	do
		ior_processlist="${ior_processlist} ${procnum}"
	done
	cp ${processlistfile} "${batchdir}"
else
	echo "${ior_processlist}" > "${batchdir}/ior.p.0_default.txt"
fi
if [ ! -z "${ior_filesystemlistfile}" ]
then
	ior_filesystemlist=""
	for filesystem in $(cat ${ior_filesystemlistfile})
	do
		ior_filesystemlist="${ior_filesystemlist} ${filesystem}"
	done
	cp ${ior_filesystemlistfile} "${batchdir}"
else
	echo "${ior_filesystemlist}" > "${batchdir}/ior.f.0_default.txt"
fi
if [ ! -z "${ior_runnerlistfile}" ]
then
	cp ${ior_runnerlistfile} "${batchdir}"
else
	echo "${runnerlist}" > "${batchdir}/ior.r.0_default.txt"
fi
if [ ! -z "${ior_optionlistfile}" ]
then
	cp ${ior_optionlistfile} "${batchdir}"
else
	echo "${ior_optionlist}" > "${batchdir}/ior.o.0_default.txt"
fi
if [ ! -z "${ior_runnerlistfile}" ]
then
	while read -r command
	do
		for filesystem in ${ior_filesystemlist}
		do
			if [ ! -z ${ior_optionlistfile} ]
			then
				while read -r options
				do
					echo "${command} -f ${filesystem} -o ${options} ${ior_processlist}"
					if [ "${debug}" -lt "${DEBUGNOEXECUTE}" ]
					then
						${command} -f ${filesystem} -o "${options}" ${ior_processlist}
					fi
				done < ${ior_optionlistfile}
			else
				echo "${command} -f ${filesystem} -o ${ior_optionlist} ${ior_processlist}"
				if [ "${debug}" -lt "${DEBUGNOEXECUTE}" ]
				then
					${command} -f ${filesystem} -o "${ior_optionlist}" ${ior_processlist}
				fi
			fi
		done
	done < ${ior_runnerlistfile}
else
	command=${runnerlist}
	for filesystem in ${ior_filesystemlist}
	do
		if [ ! -z ${ior_optionlistfile} ]
		then
			while read -r options
			do
				echo "${command} -f ${filesystem} -o ${options} ${ior_processlist}"
				if [ "${debug}" -lt "${DEBUGNOEXECUTE}" ]
				then
					${command} -f ${filesystem} -o "${options}" ${ior_processlist}
				fi
			done < ${ior_optionlistfile}
		else
			echo "${command} -f ${filesystem} -o ${ior_optionlist} ${ior_processlist}"
			if [ "${debug}" -lt "${DEBUGNOEXECUTE}" ]
			then
				${command} -f ${filesystem} -o "${ior_optionlist}" ${ior_processlist}
			fi
		fi
	done
fi
grep "${batchstring}" "${TESTLOG}" > "${batchdir}/testlog.txt"
cd ${batchdir}
do_extract
grep FAIL testlog.txt
