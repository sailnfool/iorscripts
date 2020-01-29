#!/bin/bash   
################################################################################
# Author: Robert E. Novak
# email: novak5@llnl.gov, sailnfool@gmail.com
#
# Run the mdtest (metadata test) script repeatedly across a set of
# processees that can be distributed across nodes.
#
# This script will create a directory at the same level as the directory in
# which the compiled binaries are stored.  The name of the directory is:
# testdir
# 
# In this directory we will install all of the test results and files
# necessary for performing testing.
#
# In the testdir we will maintain an etc directory where we will store
# miscellaneous data necessary for running the testing envionrment.
#
# Each program that is under test shall write entries in a common logfiile:
#
# testdir/etc/*logfile.txt
#
# Log entries willbe single line records and will  contain multiple fields
# and the fields will be separated by a vertical pipe character "|" to
# separate the fields of the record.  Every ~ 20 execution of tests, the
# log file will write out header lines that explain the purpose of each
# field in the logfile. the following is only a sample.
#
# EVENT|execname|process#|BATCH#|Test#|TimeSTAMP|Event|Specific|Fields
#
# EVENT Types
#		START Record for when the test begins
#		FINISH Record for when the test ends
#		DELTA Record that records information about the wall time of the 
#			Test - about the interval between START and FINISH
#		RATE Record that tracks information about the rate at which the processes
#			execute to insure that we are able to schedule/allocate adequate time
#			for future runs of the application
#
################################################################################
source func.errecho
source func.insufficient
source func.procrate
source func.getprocrate
source func.logger
source func.hmsout
source func.arithmetic

USAGE="${0##*/} [-hdv] [-f <filesystem>] [-N #] -t <time> <#procs> ...\r\n
\t\trun the mdtest benchmark with default options\r\n
\t-h\tPrint this message\r\n
\t-v\tSet verbose mode. If set before -h you get verbose help\r\n
\t-d\t#\tturn on diagnostics level #\r\n
\t-f\t<filesystem>\trun mdtest against the named filesystem/\$USER\r\n
\t-p\t#\tthe minimum percentage of nodes acroos which the\r\n
\t\t\tload will be distributed\r\n
\t-N\t#\tthe number of nodes that you want to run on.\r\n
\t-t\t#\tthe number of minutes of CPU time you want to request\r\n"

VERBOSE_USAGE="${0##*/} Debugging, time information and default information\r\n
\t-d\t8\tTurns on the bash \"set -x\" flag.\r\n
\t-d\t6\tRuns this script in testing mode to show what would run but\r\n
\t\t\tnot actually run.\r\n
\t-f\t<fs>\tdefaults to a file system of /p/lustre3\r\n
\t-t\r<minutes>\tActually just passes through to srun. Defaults to\r\n
\t\t\tone minute. See -t or --time so see all of the different options\r\n
\t\t\tlike min:sec\r\n"
####################
# There must be at least one argument to this script which tells the number
# of processes to run for mdtest.
####################
runner_NUMARGS=1

####################
# debug flag for this script.
####################
runner_debug=0

####################
# Specify the default parallel file system under test in case the user 
# forgets to specify one.
####################
filesystem=/p/lustre3/

####################
# The default percentage of nodes as a percentage of processes.
# If we have 100 processes and the MinNodesPercent is 25, then
# the MinNodeDivisor is 4, so that there will be 25 Nodes requested
####################
((MinNodesPercent=25))
((MinNodesDivisor= 100 / MinNodesPercent))

####################
# This flag is set if we are only performing testing of the script
####################
runner_testing=FALSE

####################
# This is the number of nodes that we will ask for from srun
# It is changed subject to MinNodesPercent and capped by MaxNodes
# Note that the -N option can override the above computation.
####################
srun_NODES="1"

####################
# set new_options to a null string.  If the user overrides the options
# the non-null value is the signal to replace the defaults.
####################
new_options=""

####################
# this becomes true if the user selects a hard coded number of nodes
# in the script command line "-N"
####################
setnodes=FALSE

####################
# The default is to ask for 1 minute of run time from srun
# This script goes through computations to insure that it has
# an accurate estimate of the amount of time per process.
####################
srun_time=1

####################
# Turn on runner verbose mode to give more complete help
####################
runner_verbose=FALSE

####################
# These are the getopt flags processed by mdrunner.  They are hopefully
# adequately understandable from the (-h) flag.
####################
runner_optionargs="hvt:d:f:p:N:o:"

while getopts ${runner_optionargs} name
do
	case $name in
		d)	# Debugging
			FUNC_VERBOSE="${OPTARG}" # see func.errecho
			runner_debug="${OPTARG}"
			if [ ${runner_debug} -ge 9 ]
			then
				set -x
			fi
			if [ ${runner_debug} -ge 6 ]
			then
				runner_testing=TRUE
			fi
			;;
		f)	# Fileystem
			filesystem="${OPTARG}"
			;;
    h)	# Help
			echo -en ${USAGE}
			if [ "${runner_verbose}" = "TRUE" ]
			then
				echo -en ${VERBOSE_USAGE}
			fi
			exit 0
			;;
		N)	# Number of Nodes FIXED, not calculated
			srun_NODES="${OPTARG}"
			setnodes=TRUE
			;;
		o)	# replace default options for mdtest
			new_options="${OPTARG}"
			;;
		p)	# percentage of Nodes from processes
			if [[ ! "${OPTARG}" =~ -?[0-9]+ ]]
			then
				errecho ${LINENO} "You must specify a numeric argument for -p"
				echo -en ${USAGE}
				exit 1
			fi
			((MinNodesDivisor= 100 / "${OPTARG}"))
			;;
		t)	# time specification.  Should be checked with a regular expression
				# that accepts a number or a time specification in HH:MM:SS
			srun_time="${OPTARG}"
			;;
		v)	# Verbose mode
			runner_verbose=TRUE
			;;
		\?)	# Invalid
			errecho "-e" ${LINENO} "invalid option: -$OPTARG"
			errecho "-e" ${LINENO} ${USAGE}
			exit 1
			;;
	esac
done
####################
# skip past the optional arguments processed above.
####################
shift $((OPTIND-1))

####################
# Verify that there is at least one non-option command
####################
if [ $# -lt ${runner_NUMARGS} ]
then
	errecho "-e" ${LINENO} "You must provide at least one argument that describes\r\n
the number of processes you want to run for testing\r\n"
	errecho "-e" ${LINENO} ${USAGE}
	insufficient ${LINENO} ${FUNCNAME} ${runner_NUMARGS} $@
fi

####################
# Collect the time we start the script to use as part of the name of the 
# directory where the results are collected. Note that the timestamp is
# in UCT (Greenwich Time)
####################
starttime=$(date -u "+%Y%m%d.%H%M%S")

####################
# when we built mdtest, it was placed in a directory relative to the
# home directory as part of ior.
# 
# This could be enhanced to look for the ior executable or the .git
# that is tied to github.com/hpc/ior to make it more portable
####################
iorhomedir=$HOME/tasks/ior

####################
# the directory where binaries (bin) and libraries (lib) were placed
####################
iorinstalldir=${iorhomedir}/install.ior

####################
# where the mdtest bin (exec) file is found
####################
mdbindir=${iorinstalldir}/bin

####################
# the actual executable, full path with name
####################
mdexec=${mdbindir}/mdtest
mdbase=${mdexec##*/}	# Yes it could have been just mdtest

####################
# We generate an uppercase version of the executable basename in order
# to have files that are used/generated by the testing process be
# distinctive in the testing directory.
# Note that this version of tr makes it language independent
####################
upper_exec=$(echo ${mdbase}|tr [:lower:] [:upper:])

####################
# we will place the testing directory at the same level as the installation
# directory, not as a subset of the installation.
#
# Note that we will use realpath to help shorten the names in the messages
####################
iortestdir=$(realpath ${iorinstalldir}/../testdir)
ioretcdir=${iortestdir}/etc
export IOR_TESTDIR=${iortestdir}
export IOR_ETCDIR=${ioretcdir}

####################
# If the test directory is not yet created, then make it.
####################
mkdir -p ${iortestdir} ${ioretcdir}

####################
# Bump the test number so that we know the number of tests that we have
# run.  Multiple copies of this script could run simultaneously so we
# insure that we get a good update without race conditions.
#
# Create a lock file so that two different scripts don't update the test
# number
####################
# This file helps identify which background process created the lock file
# in case it is canceled and leaves a lock file in place.
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
mdtestnumberfile=${ioretcdir}/${upper_exec}.TESTNUMBER

####################
# if it does not exist, initialize it with a zero value
# otherwise retrieve the number in the file.
####################
if [ ! -f ${mdtestnumberfile} ]
then
	mdtestnumber=0
else
	mdtestnumber=$(cat ${mdtestnumberfile})
fi

####################
# bump the test number and stuff it back in the file.
# I need testing to make sure that I can eliminate the echo
####################
((++mdtestnumber))>/dev/null
echo ${mdtestnumber} > ${mdtestnumberfile}

####################
# retrieve the current test number and stuff it in a test string for
# identifying the results directory
####################
mdteststring="${USER}-$(printf '%04d' ${mdtestnumber})"

####################
# Now we can release the lock and the lock info
####################
rm -f ${ioretcdir}/{lock,lock_process_${USER}_$$}

####################
# If we are invoked as a batch of runs, then the caller will set
# a batchstring that we can use as the directory name for the batch
# that we are part of.  If they did not set this, it is a null string.
# This takes advantage of the fact taht all directory/file parsing
# in both Unix and Linux collapses // to /
# If this is passes as a parameter to a sub-shell or function it
# should always be placed in "" to avoid mismatched parameter counts
####################
mdbatchstring=${mdbatchstring:=""}

####################
# This is the name of the directory where all of the results from this
# batch of runs will be placed.
# In this same directory, we will place the directives file (if used)
# and the information about the version of IOR that is under test.
####################
mdtestresultdir="${iortestdir}/${mdbatchstring}/${starttime}_${mdteststring}"
mkdir -p ${mdtestresultdir}

####################
# Get the date that the executable was built and the
# version string embedded in the binary
# store this information in the testresultdirectory in a file called
# VERSION_info.txt
####################
mdmetadatafile=${mdtestresultdir}/${upper_exec}.VERSION.info.txt
iorbuilddate=$(sourcedate -t ${iorinstalldir})
echo "mdtest Build Date information" >> ${mdmetadatafile}
echo ${iorbuilddate} >> ${mdmetadatafile}

####################
#
# This next is slightly brain damaged.  scontrol shows all partitions and
# each one can have MaxUsers.  Arbitrarily take the last one until I can
# figure out how to know which partition I am running in and how I can
# show the information about ONLY that partition.
#
# This is HIGHLY dependent on srun vs. mpirun
#
# there is a moderate amount of parsing to figure out which is the 
# default partition.  We are punting on that for now.
####################
if [ $(which srun)>/dev/null ]
then
	MaxNodes=$(scontrol show partition | \
		sed -n -e '/MaxNodes/s/^[ ]*MaxNodes=\([^ 	]*\).*/\1/p' | tail -1)
else
	errecho ${FUNCNAME} ${LINENO} "Could not find srun on this machine"
	errecho ${FUNCNAME} ${LINENO} "Are you sure you are on the right machine?"
	errecho ${FUNCNAME} ${LINENO} "If you need to run mpirun. fix the code here"
	exit 1
fi

####################
# get the basename of the filesystem under test
####################
fsbasename=${filesystem##*/}

####################
# sanity check to make sure that the file sytem exists
####################
if [ ! -d ${filesystem} ]
then
	errecho ${LINENO} "Could not detect filesystem (-f) = ${filesystem}"
	errecho -e ${LINENO} ${USAGE}
	exit 1
fi
mount | grep ${fsbasename} >> ${mdmetadatafile}

####################
# Standard options we don't override
####################
mdopts="-b 2 -z 3 -I 10 -i 5"
if [ ! -z "${new_options}" ]
then
	mdopts="${new_options}"
fi

####################
# Build the list of the processes that will be used
# on successive tests.
####################
testcounts=""
for i in $*
do
	testcounts="${testcounts} $i"
done

####################
# for each of the counts of the number of processes that will be used for
# testing, generate an 'srun' or 'mpirun' to run the ior test.
# Note that this script is highly specific to LLNL.  See MaxNodes above.
####################
for numprocs in ${testcounts}
do

	if [ ${numprocs} -eq 0 ]
	then
		###################
		# Nothing to do
		###################
		exit 0
	fi
	####################
	# Divide the number of processes for this test by the MinNodesDivisor
	# from the -p option to this script.  E.G. if you specify 10 processes
	# and a percentage of 50% (-p 50), then the MinNodesDivisor was set
	# to 100/50 -> 2, so that MinNodes would be set to 5
	####################
	((MinNodes=numprocs / MinNodesDivisor))
# 	errecho ${LINENO} "numprocs = ${numprocs}"
# 	errecho ${LINENO} "MinNodesDivisor = ${MinNodesDivisor}"
# 	errecho ${LINENO} "MinNodes = ${MinNodes}"
	# MinNodes=$(expr ${numprocs} '/' ${MinNodesDivisor})

	####################
	# If the user specified nodes manually (-N #), then you will use
	# that number (set above), otherwise we will set the number of srun_NODES
	#to the calculated MinNodes 
	####################
	if [ "${setnodes}" = "FALSE" ]
	then
		srun_NODES=${MinNodes}
	fi
#	errecho ${LINENO} "srun_NODES=${srun_NODES}"

	####################
	# This is a safety check to insure that the number of NODES is not null or
	# zero.  We could exit at this point if either of these is true.
	####################
	if [ -z "${srun_NODES}" ]
	then
		srun_NODES=1
	fi
	if [ ${srun_NODES} -eq 0 ]
	then
		srun_NODES=1
	fi
#	errecho ${LINENO} "srun_NODES=${srun_NODES}"
#	errecho ${LINENO} "MaxNodes=${MaxNodes}"

	####################
	# Check to see if the user requested number of Nodes is greater than
	# the maximum nodes available on the machine under test.
	####################
	if [ ${srun_NODES} -gt ${MaxNodes} ]
	then
		errecho ${LINENO} \
			"Exceeded Maximum available nodes, Requested ${srun_NODES}, Max=${MaxNodes}"
		exit 1
	fi

	####################
	# Encode the number of nodes and processes into zero prefixed strings
	# (E.G. 001 or 091) so that sort orders can be correct later.
	####################
	NODESTRING="$(printf "%03d" ${srun_NODES})"
	PROCSTRING="$(printf "%03d" ${numprocs})"

	####################
	# Based on observed behavior on Corona, we will need approximately
	# one minute for each 100 processes to complete.  Let's modify the
	# user specified run time.
	####################
	mdtestlog=${ioretcdir}/${upper_exec}.testlog.txt
	default_procrate_filename=${upper_exec}.${fsbasename}.procrate.txt
	default_procrate_minfilename=${upper_exec}.${fsbasename}.default.txt
	defaultprocratefile=${IOR_ETCDIR}/${default_procrate_minfilename}
	if [ ! -e ${defaultprocratefile} ]
	then
		echo "150" > ${defaultratefile}
	fi
	defaultprocrate=$(cat ${defaultprocratefile})
	export IOR_TESTLOG=${mdtestlog}

#	export IOR_PROCRATE=${IOR_TESTDIR}/${default_procrate_filename}
#	errecho ${LINENO} ${FUNCNAME} "mdtestlog=${mdtestlog}"
#	errecho ${LINENO} ${FUNCNAME} "default_procrate_filename=${default_procrate_filename}"
#	errecho ${LINENO} ${FUNCNAME} "IOR_TESTLOG=${IOR_TESTLOG}"
#	errecho ${LINENO} ${FUNCNAME} "IOR_PROCRATE=${IOR_PROCRATE}"
	procrate_value=$(get_procrate "${mdbase}" "${fsbasename}" "${numprocs}")

	####################
	# if it came back null, there is no value in the datbase for this test for
	# this filesystem.  Generate a default entry.
	####################
	if [ -z "${procrate_value}" ]
	then
		echo $(procrate "${mdbase}" "$$" "${mdbatchstring}" "${mdtestnumber}" "${fsbasename}" ${defaultprocrate} "${numprocs}")>/dev/null
		procrate_value=$(get_procrate "${mdbase}" "${fsbasename}" "${numprocs}")
	fi

	####################
	# if it came back zero, there is an invalid value in the database for
	# this test for this filesystem.  Generate a default entry.
	####################
	if [ ${procrate_value} -eq 0 ]
	then
		echo $(procrate "${mdbase}" "$$" "${mdbatchstring}" "${mdtestnumber}" "${fsbasename}" ${defaultprocrate} "${numprocs}")>/dev/null
		procrate_value=$(get_procrate "${mdbase}" "${fsbasename}" "${numprocs}")
		if [ "${procrate_value}" -eq 0 ]
		then
			errecho ${FUNCNAME} ${LINENO} "Invalid lookup from get_procrate, procrate_value=${procrate_value}"
			exit 1
		fi
	fi
	errecho ${FUNCNAME} ${LINENO} "procrate_value=${procrate_value}"
	####################
	# based on the rate in the database for this filesystem, retrieve the rate
	# multiply it by the number of processes to get the number of processes
	# per hour, then divide by 100000 to get the number of seconds for this 
	# many processes.
	####################
	((band=100))
	((centurion=$(func_introundup ${numprocs} ${band})))
	errecho ${FUNCNAME} ${LINENO} "centurion=${centurion}"
	((decimicroseconds=procrate_value / centurion))
	errecho ${FUNCNAME} ${LINENO} "decimicroseconds=${decimicroseconds}"
	((srun_time_decimicroseconds=decimicroseconds*numprocs))
	errecho ${FUNCNAME} ${LINENO} "srun_time_decimicroseconds=${srun_time_decimicroseconds}"
	((srun_time_seconds=srun_time_decimicroseconds / 100000))
	errecho ${FUNCNAME} ${LINENO} "srun_time_seconds=${srun_time_seconds}"
	((srun_time_seconds+=srun_time_decimicroseconds % 100000))
	((srun_time_seconds*=4))
	errecho ${FUNCNAME} ${LINENO} "srun_time_seconds=${srun_time_seconds}"

	####################
	# This is purely defensive, there is no way that the number of seconds
	# should be zero if procrate_value was not zero
	####################
	if [ ${srun_time_seconds} -le 0 ]
	then
		errecho ${LINENO} "Invalid run time: srun_time_seconds=${srun_time_seconds}"
		exit 1
	fi

	####################
	# Check if the number of seconds is more than 24 hours. If so, we need to
	# modify the time parameter to the srun/mpirun
	####################
	((dayseconds=24*60*60))
	if [ "${srun_time_seconds}" -ge ${dayseconds} ]
	then
		errecho ${FUNCNAME} ${LINENO} "Projected run time exceeds 24 hours, quitting"
		exit 1
	fi

	####################
	# Note that this converts the number of seconds into HMS values.
	####################
	new_time=$(hmsout "${srun_time_seconds}" "seconds")
	errecho ${FUNCNAME} ${LINENO} "Adjusting time request to ${new_time}"
	srun_time=${new_time}

	####################
	# The test suffix encodes the number of nodes, processes and requested
	# test time into the name of the test file where results are stored.
	####################
	testnamesuffix="_N_${NODESTRING}_p_${PROCSTRING}_t_${srun_time}"

	####################
	# The test file is placed in the result directory.  The name of the file
	# is prefixed with 'ior' to distinguish it from mdtest ('md') or from 
	# macsio ('mac') testing
	####################
	mdtestname="${mdtestresultdir}/${upper_exec}.${fsbasename}_${testnamesuffix}.txt"

	####################
	# This is specific to mdtest if an aborted prior test left garbage
	####################
	dirhead=${filesystem}/$USER/md.seq
	if [ -d ${dirhead} ]
	then
		errecho ${FUNCNAME} ${LINENO} "A previous run must have aborted without cleanup"
		errecho ${FUNCNAME} ${LINENO} "$(find ${dirhead} -type d -print | wc -l) directories left over"
		errecho ${FUNCNAME} ${LINENO} "$(find ${dirhead} -type f -print | wc -l) files left over"
		errecho ${FUNCNAME} ${LINENO} "Cleaning up"
		echo ${FUNCNAME} ${LINENO} "Cleaning up" | tee -a ${mdtestname}
		time rm -rf ${dirhead} 2>&1 | tee -a ${mdtestname}
	fi

	####################
	# echo out the name of the srun command that will be issued
	####################
 	echo "srun -n ${numprocs} -N ${srun_NODES} -t ${srun_time} ${mdexec} ${mdopts} -d ${filesystem}/$USER/md.seq | tee -a ${mdtestname}" | tee -a ${mdtestname}

	####################
	# If we are not just testing, then run the test.
	####################
	export IOR_TESTLOG=${mdtestlog}
	if [ "${runner_testing}" = "FALSE" ]
	then
		date_began=$(date)
		$(logger "START" "${mdbase}" "$$" "${mdbatchstring}" "${mdtestnumber}" "${fsbasename}" "${date_began}" "${numprocs}" "${srun_NODES}")
  	srun -n "${numprocs}" -N "${srun_NODES}" -t "${srun_time}" "${mdexec}" ${mdopts} -d ${filesystem}/$USER/md.seq | tee -a "${mdtestname}"
		date_finished=$(date)
		$(logger "FINISH" "${mdbase}" "$$" "${mdbatchstring}" "${mdtestnumber}" "${fsbasename}" "${date_finished}" "${numprocs}" "${srun_NODES}")
  	time_delta=$(date -d @$(( $(date -d "${date_finished}" +%s) - $(date -d "${date_began}" +%s) )) -u +'%H:%M:%S')
  	time_delta_seconds=$(date -d @$(( $(date -d "${date_finished}" +%s) - $(date -d "${date_began}" +%s) )) -u +'%s')
  	#time_delta_seconds=$(( $(date -d "${date_finished}" +%s) - $(date -d "${date_began}" +%s) ))
		$(logger "DELTA" "${mdbase}" "$$" "${mdbatchstring}" "${mdtestnumber}" "${fsbasename}" "${time_delta}" "${time_delta_seconds}" "${numprocs}")
		echo $(procrate "${mdbase}" "$$" "${mdbatchstring}" "${mdtestnumber}" "${fsbasename}" "${time_delta_seconds}" "${numprocs}")>/dev/null
	fi
done
exit 0
# vim: set syntax=bash, ts=2, sw=2, lines=55, columns=120,colorcolumn=78
