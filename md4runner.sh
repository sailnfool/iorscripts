#!/bin/bash   
#######################################################################
# Author: Robert E. Novak
# email: novak5@llnl.gov, sailnfool@gmail.com
#
# Run the mdtest (metadata test) script repeatedly across a set of
# processees that can be distributed across nodes.
#
# This script will create a directory at the same level as the
# directory in which the compiled binaries are stored.  The name
# of the directory is:
#
# testdir
# 
# In this directory we will install all of the test results and files
# necessary for performing testing.
#
# In the testdir we will maintain an etc directory where we will store
# miscellaneous data necessary for running the testing envionrment.
#
# Each program that is under test shall write entries in a common
# logfiile:
#
# testdir/etc/*logfile.txt
#
# Log entries willbe single line records and will  contain multiple
# fields and the fields will be separated by a vertical pipe
# character "|" to separate the fields of the record.  Every ~20
# execution of tests, the log file will write out header lines
# that explain the purpose of each field in the logfile. The
# following is only a sample.
#
# EVENT|execname|process#|BATCH#|Test#|TimeSTAMP|Event|Specific|Fields
#
# EVENT Types
#		START Record for when the test begins
#		FINISH Record for when the test ends
#		DELTA Record that records information about the wall time of the 
#			Test - about the interval between START and FINISH
#		RATE Record that tracks information about the rate at which the
#     processes	execute to insure that we are able to
#     schedule/allocate adequate time	for future runs of the
#     application
#
#######################################################################
source func.global2
source func.errecho
source func.insufficient
source func.logger
source func.arithmetic
source func.hmsout

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
\t-d\t6\tRuns this script in testing mode to show what would run\r\n
\t\t\tbut not actually run.\r\n
\t-f\t<fs>\tdefaults to a file system of /p/lustre3\r\n
\t-t\r<minutes>\tActually just passes through to srun. Defaults to\r\n
\t\t\tone minute. See -t or --time so see all of the different options\r\n
\t\t\tlike min:sec\r\n"
####################
# There must be at least one argument to this script which tells
# the number of processes to run for mdtest.
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
((MinNodesDivisor=100/MinNodesPercent))

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
		t)	# time specification.  Should be checked with a
				# regular expression that accepts a number or a time
				# specification in HH:MM:SS
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
	errecho "-e" ${FUNCNAME} ${LINENO} \
		"You must provide at least one argument that describes\r\n
the number of processes you want to run for testing\r\n"
	errecho "-e" ${FUNCNAME} ${LINENO} ${USAGE}
	insufficient ${FUNCNAME} ${LINENO} ${runner_NUMARGS} $@
fi

####################
# Collect the time we start the script to use as part of the name
# of the directory where the results are collected. Note that the
# timestamp is in UCT (Greenwich Time)
####################
starttime=$(date -u "+%Y%m%d.%H%M%S")


####################
# Create a lock file so that two different scripts don't update the test
# number
####################
echo $(func_getlock) >> $IOR_ETCDIR/lockerrs

####################
# if it does not exist, initialize it with a zero value
# otherwise retrieve the number in the file.
####################
if [ ! -f ${MD_TESTNUMBERFILE} ]
then
	mdtestnumber=0
else
	mdtestnumber=$(cat ${MD_TESTNUMBERFILE})
fi

####################
# bump the test number and stuff it back in the file.
# I need testing to make sure that I can eliminate the echo
####################
((++mdtestnumber))>/dev/null
echo ${mdtestnumber} > ${MD_TESTNUMBERFILE}

echo $(func_releaselock)

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
x="${IOR_TESTDIR}/${mdbatchstring}/${starttime}_${mdteststring}"
mdtestresultdir="${x}"
mkdir -p ${mdtestresultdir}

####################
# Get the date that the executable was built and the
# version string embedded in the binary
# store this information in the testresultdirectory in a file called
# VERSION_info.txt
####################
iorbuilddate=$(sourcedate -t ${IOR_INSTALLDIR})

echo $(func_getlock) >> $IOR_ETCDIR/lockerrs
echo "mdtest Build Date information" >> ${MD_METADATAFILE}
echo ${iorbuilddate} >> ${MD_METADATAFILE}
echo $(func_releaselock)

####################
#
# This next is slightly brain damaged.  scontrol shows all partitions
# and each one can have MaxUsers.  Arbitrarily take the last one until
# I can figure out how to know which partition I am running in and how
# I can show the information about ONLY that partition.
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
	errecho ${FUNCNAME} ${LINENO} \
		"Could not find srun on this machine"
	errecho ${FUNCNAME} ${LINENO} \
		"Are you sure you are on the right machine?"
	errecho ${FUNCNAME} ${LINENO} \
		"If you need to run mpirun. fix the code here"
	exit 1
fi

####################
# get the basename of the filesystem under test
####################
fsbase=${filesystem##*/}

####################
# sanity check to make sure that the file sytem exists
####################
if [ ! -d ${filesystem} ]
then
	errecho ${FUNCNAME} ${LINENO} \
		"Could not detect filesystem (-f) = ${filesystem}"
	errecho -e ${FUNCNAME} ${LINENO} ${USAGE}
	exit 1
fi
echo $(func_getlock) >> $IOR_ETCDIR/lockerrs
mount | grep ${fsbase} >> ${MD_METADATAFILE}
echo $(func_releaselock) >> ${IOR_ETCDIR}/lockerrs

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
# for each of the counts of the number of processes that will be
# used for testing, generate an 'srun' or 'mpirun' to run the
# mdtest test.
# Note that this script is highly specific to LLNL.
# See MaxNodes above.
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
	# Divide the number of processes for this test by the
	# MinNodesDivisor # from the -p option to this script.  E.G. if
	# you specify 10 processes and a percentage of 50% (-p 50), then
	# the MinNodesDivisor was set to 100/50 -> 2, so that MinNodes
	# would be set to 5
	####################
	((MinNodes=numprocs / MinNodesDivisor))
	((MinNodes=(((numprocs%MinNodesDivisor>0)?1:0))))

	####################
	# If the user specified nodes manually (-N #), then you will use
	# that number (set above), otherwise we will set the number of
	# srun_NODES to the calculated MinNodes 
	####################
	if [ "${setnodes}" = "FALSE" ]
	then
		srun_NODES=${MinNodes}
	fi
  #	errecho ${FUNCNAME} ${LINENO} "srun_NODES=${srun_NODES}"

	####################
	# This is a safety check to insure that the number of NODES is
	# not null or zero.  We could exit at this point if either of
	# these is true.
	####################
	if [ -z "${srun_NODES}" ]
	then
		srun_NODES=1
	fi
	if [ ${srun_NODES} -eq 0 ]
	then
		srun_NODES=1
	fi
  #	errecho ${FUNCNAME} ${LINENO} "srun_NODES=${srun_NODES}"
  #	errecho ${FUNCNAME} ${LINENO} "MaxNodes=${MaxNodes}"

	####################
	# Check to see if the user requested number of Nodes is greater than
	# the maximum nodes available on the machine under test.
	####################
	if [ ${srun_NODES} -gt ${MaxNodes} ]
	then
		errecho ${FUNCNAME} ${LINENO} \
			"Exceeded Maximum available nodes"
		errecho ${FUNCNAME} ${LINENO} \
			"Requested ${srun_NODES}, Max=${MaxNodes}"
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
	fileprefix=${MD_UPPER}.${fsbase}

	procdefault_file=${IOR_ETCDIR}/${fileprefix}.${PROCDEFAULT_SUFFIX}

	if [ ! -r ${procdefault_file} ]
	then
		errecho ${FUNCNAME} ${LINENO} "File Not Found ${procdefault_file}"
		errecho ${FUNCNAME} ${LINENO} \
			"Need a Default Band (e.g. 100 processes, default millisconds"
		errecho ${FUNCNAME} ${LINENO} \
			"per process and the amount by which to increase guess times"
		errecho ${FUNCNAME} ${LINENO} \
			"after failures"

		####################
		# Instead of exiting we could emit a default file here
		####################
		echo $(func_getlock) >> $IOR_ETCDIR/lockerrs
		echo "100|300|20" > ${procdefault_file}
		echo $(func_releaselock) >> ${IOR_ETCDIR}/lockerrs
		#exit 1
	fi
	linesread=0
	OLDIFS=$IFS
	IFS="|"
	while read -r band default percent
	do
		export PROC_BAND=${band}
		export DEFAULT_MS=${default}
		export FAIL_PERCENT=${percent}
		((++linesread))
	done < ${procdefault_file}
	IFS=$OLDIFS

	if [ ${linesread} -eq 0 ]
	then
		errecho ${FUNCNAME} ${LINENO} \
			"Could not read ${procdefault_file}"
		exit 1
	fi

	procrate_file=${IOR_ETCDIR}/${fileprefix}.${PROCRATE_SUFFIX}

	if [ ! -r ${procrate_file} ]
	then
		errecho ${FUNCNAME} ${LINENO} \
			"File Not found ${procrate_file}"
		errecho ${FUNCNAME} ${LINENO} \
			"Creating a on-line default table"
		echo "100|${DEFAULT_MS}|${DEFAULT_MS}|GUESS" > ${procrate_file}
	fi
	linesread=0
	OLDIFS=$IFS
	IFS="|"
	while read -r band low high gob
	do
		((++linesread))
		lo_ms[$band]=$low
		hi_ms[$band]=$high
		gobs[$band]=$gob
	done < ${procrate_file}
	IFS=$OLDIFS

	if [ ${linesread} -eq 0 ]
	then
		errecho ${FUNCNAME} ${LINENO} \
			"Could not read ${procrate_file}"
		exit 1
	fi

	band=$(func_introundup ${numprocs} ${PROC_BAND})

	if [ ! ${hi_ms[${band}]+_} ]
	then
		lo_ms[${band}]=${DEFAULT_MS}
		hi_ms[${band}]=${DEFAULT_MS}
		gobs[${band}]="GUESS"
	fi

	errecho ${FUNCNAME} ${LINENO} \
		"hi_ms[$band]=${hi_ms[$band]}"

	((milliseconds=hi_ms[$band]*numprocs))
	((srun_time_seconds=milliseconds/one_ms_second))
	((srun_time_second+=(((milliseconds%one_ms_second>0)?1:0))))

	####################
	# This is purely defensive, there is no way that the number of
  # seconds should be zero if hi_ms[$band] was not zero
	####################
	if [ ${srun_time_seconds} -le 0 ]
	then
		errecho ${FUNCNAME} ${LINENO} \
      "Invalid run time: srun_time_seconds=${srun_time_seconds}" >&2
		errecho ${FUNCNAME} ${LINENO} \
      "hi_ms[$band]=${hi_ms[$band]}" >&2
		errecho ${FUNCNAME} ${LINENO} \
      "numprocs=${numprocs}" >&2
		errecho ${FUNCNAME} ${LINENO} \
      "milliseconds=${milliseconds}" >&2
		exit 1
	fi

	####################
	# Check if the number of seconds is more than 24 hours. If so, we
	# need to modify the time parameter to the srun/mpirun
	####################
	((dayseconds=24*60*60))
	if [ "${srun_time_seconds}" -ge ${dayseconds} ]
	then
		errecho ${FUNCNAME} ${LINENO} \
			"Projected run time exceeds 24 hours, quitting"
		exit 1
	fi

	####################
	# Note that this converts the number of seconds into HMS values.
	####################
	new_time=$(hmsout "${srun_time_seconds}" "seconds")
	errecho ${FUNCNAME} ${LINENO} "Adjusting time request to ${new_time}"
	srun_time=${new_time}

	####################
	# The test suffix encodes the number of nodes, processes and
	# requested test time into the name of the test file where
	# results are stored.
	####################
	testnamesuffix="_N_${NODESTRING}_p_${PROCSTRING}_t_${srun_time}"

	####################
	# The test file is placed in the result directory.  The name of
	# the file is prefixed with 'mdtest' to distinguish it from ior
	# or from macsio ('mac') testing
	####################
x="${mdtestresultdir}/${MD_UPPER}.${fsbase}_${testnamesuffix}.txt"
	mdtestname="${x}"

	####################
	# Cleanup from prior runs
	####################
	dirhead=${filesystem}/$USER/md.seq
	if [ -d ${dirhead} ]
	then
			dircnt="$(find ${dirhead} -type d -print | wc -l)"
			filecnt"$(find ${dirhead} -type f -print | wc -l)"
		if [ $dircnt -ge 1 ]
		then
			if [ $filecnt -gt 0 ]
			then
				errecho ${FUNCNAME} ${LINENO} \
			"A previous run must have aborted without cleanup"
				errecho ${FUNCNAME} ${LINENO} \
			"$(find ${dirhead} -type d -print | wc -l) directories left over"
				errecho ${FUNCNAME} ${LINENO} \
			"$(find ${dirhead} -type f -print | wc -l) files left over"
				errecho ${FUNCNAME} ${LINENO} "Cleaning up"
				echo ${FUNCNAME} ${LINENO} "Cleaning up" | tee -a ${mdtestname}
			fi
		fi
		time rm -rf ${dirhead} 2>&1 | tee -a ${mdtestname}
	fi

	####################
	# echo out the name of the srun command that will be issued
	####################
 	echo "srun -n ${numprocs} -N ${srun_NODES} -t ${srun_time}\
${MD_EXEC} ${mdopts} -d ${filesystem}/$USER/md.seq | \
tee -a ${mdtestname}" | tee -a ${mdtestname}
	srun_status=$?

	####################
	# If we are not just testing, then run the test.
	####################
	if [ "${runner_testing}" = "FALSE" ]
	then
		date_began=$(date)

		####################
		# Log the START
		####################
		$(logger "START" "${MD_BASE}" "$$" "${mdbatchstring}" \
"${mdtestnumber}" "${fsbase}" "${date_began}" "${numprocs}"\
"${srun_NODES}")

		####################
		# Run the benchmark test
		####################
  	srun -n "${numprocs}" -N "${srun_NODES}" -t "${srun_time}"\
"${MD_EXEC}" ${mdopts} -d ${filesystem}/$USER/md.seq | \
tee -a "${mdtestname}"
		srun_status=$?

		####################
		# We kept the completion status.  There could be many reasons
		# why the benchmark failed, but the most likely culprit is
		# exceeding the requested time. 
		####################
		if [ $srun_status -ne 0 ]
		then
			####################
			# Remember that we failed and adjust the hi_ms time for this
			# band accordingly by keeping the logged time for next run
			# at a level that is FAIL_PERCENT higher for the next time
			# we run the benchmark in this band of processes.
			####################
			completion=FAIL
			((hi_ms[$band]+=(${hi_ms[$band]}*${FAIL_PERCENT})/100))

			####################
			# Following a failure we don't have true observed time. As
			# a result, we have to mark this increased amount of time as
			# a guess.
			####################
			gobs[$band]=GUESS

			####################
			# We sort the old file before we remember it as the old file
			# This is not needed for a computational reason but it is
			# easier for people to read a sorted file
			####################
			sort -u -n -t "|" < ${procrate_file} > ${procrate_file}.old.txt
			
			####################
			# We remove the current file and write a new one dumped from
			# the Associative array where we keep the data.
			####################
			rm ${procrate_file}
			for band in "${!lo_ms[@]}"
			do
				echo \
			"${band}|${lo_ms[${band}]}|${hi_ms[${band}]}|${gobs[${band}]}" \
					>> ${PROCRATE_TMPFILE}
			done
			sort -u -n -t "|" ${PROCRATE_TMPFILE} > ${procrate_file}
			rm -f ${PROCRATE_TMPFILE}
		else

			####################
			# We will mark the successful completion we remember the success
			# or fail to mark it in the log.
			####################
			completion=SUCCESS
		fi

		####################
		# Mark the completion and log it
		####################
		date_finished=$(date)
		$(logger "FINISH" "${MD_BASE}" "$$" "${mdbatchstring}"\
"${mdtestnumber}" "${fsbase}" "${date_finished}" "${numprocs}"\
"${srun_NODES}")
		####################
		# Do date arithmetic to get the delts in HMS and in seconds
		####################
  	time_delta=$(date -d @$(( $(date -d "${date_finished}" +%s) -\
$(date -d "${date_began}" +%s) )) -u +'%H:%M:%S')
  	time_delta_seconds=$(date -d @$(( $(date -d \
"${date_finished}" +%s) - $(date -d "${date_began}" +%s) )) -u +'%s')

		####################
		# Log the delta and the rate
		####################
		$(logger "DELTA" "${MD_BASE}" "$$" "${mdbatchstring}"\
"${mdtestnumber}" "${fsbase}" "${time_delta}" "${time_delta_seconds}"\
"${numprocs}")

		####################
		# Record the new rate in the procrate table
		# We compute the number of milliseconds/process rounding up
		####################
		((new_ms=(time_delta_seconds*one_ms_second)/numprocs))
		((new_ms+=((time_delta__seconds*one_ms_second)%numprocs>0)?1:0))

		####################
		# if we have reached a new high for this band, update the high
		####################
		changed="FALSE"
		if [ ${new_ms} -gt ${hi_ms[$band]} ]
		then
			hi_ms[$band]=${new_ms}
			gobs[$band]="OBSERVED"
			changed=TRUE
		else
			####################
			# if we have reached a new low for this band, update the low
			####################
			if [ ${new_ms} -lt ${lo_ms[$band]} ]
			then
				lo_ms[$band]=${new_ms}
				gobs[$band]="OBSERVED"
				changed=TRUE
			fi
		fi
		####################
		# if the table changed, then save it.
		####################
		if [ "${changed}" = "TRUE" ]
		then
			rm ${procrate_file}
			for band in "${!lo_ms[@]}"
			do
				echo \
			"${band}|${lo_ms[${band}]}|${hi_ms[${band}]}|${gobs[${band}]}" \
					>> ${PROCRATE_TMPFILE}
			done
			sort -u -n -t "|" ${PROCRATE_TMPFILE} > ${procrate_file}
		fi
	
		####################
		# Now we log the rate from this 
		####################
		$(logger "RATE" "${MD_UPPER}" "$$" "${mdbatchstring}" \
"${mdtestnumber}" "${base}" "${srun_time}" "${numprocs}" \
"${band}" "${new_ms}" "${lo_ms[$band]}" "${hi_ms[$band]}"
	fi
done
exit 0
# vim: set syntax=bash, ts=2, sw=2, lines=55, columns=120,colorcolumn=78
