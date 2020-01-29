#!/bin/bash   
################################################################################
# Author: Robert E. Novak
# email: novak5@llnl.gov, sailnfool@gmail.com
#
# Run the ior script repeatedly across a set of processors.  The initial
# implementation takes the list of CPU sets as a command line option, E.G.:
#
# iorunner 10 20 40 80
#
# This script will create a directory at the same level as the directory
# in which the compiled binaries are stored.  THe name of the directory is:
# testdir
#
# In this directory we will install all of the test results and files 
# necessary for performing testing.
#
# in the testdire we will maintain an etc directory where we will store
# miscellaneous data necessary for running the testing environment.
#
# testdir/etc/*logfile.txt
#
# Log entries will be single line records and will contain multiple fields
# and the fields will be separate by a verticla pipe character "|" to 
# separate the fields of the record.  Every ~20 executions of tests, the
# log file will write out header lines that explain the purpose of each
# field in the logfile.  The following is only a sample.
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
# iorunner $(argsexponent 2 $(nproc --show))
# iorunner $(linear -low 10 -increment 10 -high $(nproc --all))
#
################################################################################
source func.errecho
source func.insufficient
source func.procrate
source func.getprocrate
source func.logger
source func.arithmetic
source func.hmsout

USAGE="${0##*/} [-hdvc] [-f <filesystem>] [-m #] [-N #] -t <minutes> <#procs> ...\r\n
\t\trun the ior benchmark with default options provide a list\r\n
\t\tof the number of processes.  See -p to control the # of nodes\r\n
\t\trelative to the number of processes.\r\n
\t-h\tPrint this message\r\n
\t-v\tSet verbose mode. If set before -h you get verbose help\r\n
\t-c\tSave output in CSV format\r\n
\t-d\t#\tturn on diagnostics level #\r\n
\t-f\t<filesystem>\trun ior against the named filesystem/\$USER\r\n
\t-m\t#\tthe percentage of free memory to pre-allocate to avoid\r\n
\t\t\tread cache problems\r\n
\t-o\t<opts>\tAdditional parameters to be passed directly to ior\r\n
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
\t\t\tone minute. See srun -t or --time to see all of the different options\r\n
\t\t\tlike min:sec.  Based on one platform, observations, the script now\r\n
\t\t\testimates the time at 1 minute per each one hundred processes.  Your\r\n
\t\t\tmileage may vary so you may need to tune this.\r\n
\t\t\t
\t\tThis script keeps a running count of how many times the script has been\r\n
\t\trun and uses that number in naming the directory in which the results\r\n
\t\tare run.  It uses a lock file to prevent multiple instances of the\r\n
\t\tfrom updating the count inconsistently.  If you see the script\r\n
\t\tspinning on the lock file, you may have to kill the script and\r\n
\t\tmanually remove the lock file.\r\n"

####################
# There must be at least one argument to this script which tells the number
# of processes to run for ior.
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
iorfilesystem=/p/lustre3

####################
# Standard options we don't override
####################
ioropts=" -b 16m -s 16 -F -C -e -i 5 -t 2m"
# errecho ${LINENO} "ioropts=${ioropts}" >&2

####################
# Additional ior options that can come in with -o flag
####################
ioraddopts=""

####################
# To avoid Read Cache effects, we may set the cache size to 90%
# memlimit is used to signal that the user specified a mempercent
# and we have to add the "-M" option to the ior_options
####################
mempercent=0
memlimit=FALSE

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
####################
srun_NODES="1"

####################
# this becomes true if the user selects a hard coded number of nodes
# in the script command line "-N"
####################
setnodes=FALSE

####################
# The default is to ask for 1 minute of run time from srun
####################
srun_time=1

####################
# Turn on runner verbose mode to give more complete help
####################
runner_verbose=FALSE

####################
# This is the first experimental directive option flag.  If we set
# this to TRUE (-c) then we will create an ior directive (script) to
# have the fileFormat output in CSV node instead of the verbose
# human readable mode.
####################
wantCSV=FALSE

####################
# These are the getopt flags processed by iorunner.  They are hopefully
# adequately understandable from the (-h) flag.
####################
runner_optionargs="hvct:d:f:m:o:p:N:"

while getopts ${runner_optionargs} name
do
	case $name in
		c)
			wantCSV=TRUE
			;;
		d)
			FUNC_DEBUG=${OPTARG} # see func.errecho
			runner_debug=${OPTARG}
			if [ ${runner_debug} -gt 8 ]
			then
				set -x
			fi
			if [ ${runner_debug} -ge 6 ]
			then
				runner_testing=TRUE
			fi
			;;
		f)
			iorfilesystem=${OPTARG}
			;;
    h)
			echo -en ${USAGE}
			if [ "${runner_verbose}" = "TRUE" ]
			then
				echo -en ${VERBOSE_USAGE}
			fi
			exit 0
			;;
		m)
			mempercent=${OPTARG}
			memlimit=TRUE
			;;
		N)
			srun_NODES=${OPTARG}
			setnodes=TRUE
			;;
		o)
			####################
			# Note that there may be blanks in the OPTARG
			####################
			ioraddopts="${OPTARG}"
			;;
		p)
			MinNodesDivisor=`expr 100 '/' ${OPTARG}`
			;;
		t)
			srun_time=${OPTARG}
			;;
		v)
			runner_verbose=TRUE
			;;
		\?)
			errecho "-e" ${FUNCNAME} ${LINENO} "invalid option: -$OPTARG" >&2
			errecho "-e" ${FUNCNAME} ${LINENO} ${USAGE} >&2
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
	errecho "-e" ${FUNCNAME} ${LINENO} "You must provide at least one argument that describes\r\n
the number of processes you want to run for testing\r\n"
	errecho "-e" ${FUNCNAME} ${LINENO} ${USAGE}
	insufficient ${LINENO} ${FUNCNAME} ${runner_NUMARGS} $@
	exit 1
fi

####################
# Collect the time we start the script to use as part of the name of the 
# directory where the results are collected. Note that the timestamp is
# in UCT (Greenwich Time)
####################
starttime=$(date -u "+%Y%m%d.%H%M%S")

####################
# when we built ior, it was placed in a directory relative to the
# home directory.
#
# This could be enhanced to look for the ior executable or the .git that is
# tied to github.com/hpc/ior to make it more portable
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
# the actual executable, full path with name
####################
iorexec=${iorbindir}/ior
iorbase=${iorexec##*/}	# Yes it could have been just ior

####################
# We generate an uppercase version fo the executable basename in order
# to have files that are used/generated by the testing process be 
# distinctive in the testing directory.
# Note that these parameters make the tr translation language independent
####################
upper_exec=$(echo ${iorbase}|tr [:lower:] [:upper:])

####################
# we will place the testing directory at the same level as the installation
# directory, not as a subset of the installation.
#
# Note that we will use realpath to help shorten the names in messages.
####################
export IOR_TESTDIR=$(realpath ${iorinstalldir}/../testdir)
export IOR_ETCDIR=${IOR_TESTDIR}/etc

####################
# If the test directory is not yet created, then make it.
####################
mkdir -p ${IOR_TESTDIR} ${IOR_ETCDIR}

####################
# Bump the test number so that we know the number of tests that we have
# run.  Multiple copies of this script could run simultaneously so we
# insure that we get a good update without race conditions.
#
# Create a lock file so that two different scripts don't update the test
# number
####################
# This $USER file helps identify which background process created the lock
# file in case it is canceled and leaves a lock file in place.
####################
while [ -f ${IOR_ETCDIR}/lock ]
do
	errecho ${FUNCNAME} ${LINENO} "Sleeping on lock acquistion for lock owned by" >&2
	errecho ${FUNCNAME} ${LINENO} "$(ls -l ${IOR_ETCDIR}/lock*)" >&2
	sleep 1
done
touch ${IOR_ETCDIR}/{lock,lock_process_${USER}_$$}

####################
# Use a file to keep track of the number of tests that have been run by this 
# script against the executable.
####################
iortestnumberfile=${IOR_ETCDIR}/${upper_exec}.TESTNUMBER

####################
# if it does not exist, initialize it with a zero value
# otherwise retrieve the number in the file.
####################

if [ ! -f ${iortestnumberfile} ]
then
	iortestnumber=0
else
	iortestnumber=$(cat ${iortestnumberfile})
fi

####################
# bump the test number and stuff it back in the file.
####################
((++iortestnumber))>/dev/null
echo ${iortestnumber} > ${iortestnumberfile}

####################
# retrieve the current test number and stuff it in a test string for
# identifying the results directory
####################
iorteststring="${USER}-$(printf '%04d' ${iortestnumber})"

####################
# Now we can release the lock and the lock info
####################
rm -f ${IOR_ETCDIR}/{lock,lock_process_${USER}_$$}

####################
# If we are invoked as a batch of runs, then the caller will set
# a batchstring that we can use as the directory name for the batch
# that we are part of.  If they did not set this, it is a null string
# This takes advantage of the fact that all directory/file parsing
# in both Unix and Linux collapses // to /
####################
iorbatchstring=${iorbatchstring:=""}

####################
# This is the name of the directory where all of the results from this
# batch of runs will be placed.
# In this same directory, we will place the directives file (if used)
# and the information about the version of IOR that is under test.
####################
iortestresultdir="${IOR_TESTDIR}/${iorbatchstring}/${starttime}_${iorteststring}"
mkdir -p ${iortestresultdir}

####################
# Get the date that the executable was built and the
# version string embedded in the binary
# store this information in the testresultdirectory in a file called
# VERSION_info.txt
####################
iormetadatafile=${IOR_ETCDIR}/${upper_exec}.VERSION.info.txt
iorbuilddate=$(sourcedate -t ${iorinstalldir})
iorversion=$(strings ${iorexec} | egrep '^IOR-')
echo "IOR Version info" > ${iormetadatafile}
echo ${iorversion} >> ${iormetadatafile}
echo "" >> ${iormetadatafile}
echo "IOR Build Date information" >> ${iormetadatafile}
echo ${iorbuilddate} >> ${iormetadatafile}

####################
#
# This next is slightly brain damaged.  scontrol shows all partitions and
# each one can have MaxUsers.  Arbitrarily take the last one until I can
# figure out how to know which partition I am running in and how I can
# show the information about ONLY that partition.
#
# This is HIGHLY dependent on srun vs. mpirun
#
# there is a moderate amount of parsting to figure out which is the 
# default partition.  We are punting on that for now.
####################
if [ $(which srun)>/dev/null ]
then
	MaxNodes=$(scontrol show partition | \
		sed -n -e '/MaxNodes/s/^[ ]*MaxNodes=\([^ 	]*\).*/\1/p' | tail -1)
else
	errecho ${FUNCNAME} ${LINENO} "Could not find srun on this machine" >&2
	errecho ${FUNCNAME} ${LINENO} "Are you sure you are on the right machine?" >&2
	errecho ${FUNCNAME} ${LINENO} "If you need to run mpirun. fix the code here" >&2
	exit 1
fi

####################
# get the basename of the filesystem under test
####################
fsbasename=${iorfilesystem##*/}

####################
# sanity check to make sure that the file sytem exists
####################
if [ ! -d ${iorfilesystem} ]
then
	errecho ${FUNCNAME} ${LINENO} "Could not detect filesystem (-f) = ${iorfilesystem}" >&2
	errecho -e ${FUNCNAME} ${LINENO} ${USAGE} >&2
	exit 1
fi

####################
# This override for Memory is to minimize the effects of caching
# written data to be read back.  This should really only appear on
# single node runs.  We add the -M to the end of the options above.
####################
if [ ${mempercent} -gt 0 ]
then
	ioropts="${ioropts} -M ${mempercent} "
fi
errecho ${FUNCNAME} ${LINENO} "ioropts=${ioropts}" >&2

####################
# If any additional parameters were passed in on the command line
# to be sent straight to ior, add them to the ioropts string here
####################
ioropts="${ioropts} ${ioraddopts}"
errecho ${FUNCNAME} ${LINENO} "ioropts=${ioropts}" >&2

####################
# If the user wants CSV output, then create an IOR directive file.
#
#~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~
#~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~
# This is where you can add in other directives or load a pre-canned set
# of directives from a static location.
#~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~
#~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~$~
#
####################
iordirectivefile=""
if [ "${wantCSV}" = "TRUE" ]
then
	iordirectivefile=${iortestresultdir}/directive
	echo "summaryFormat=CSV" > ${iordirectivefile}
	ioropts="${ioropts} -f ${iordirectivefile}"
fi
errecho ${FUNCNAME} ${LINENO} "ioropts=${ioropts}" >&2

####################
# Build the list of the processes that will be used
# on successive tests.
####################
testcounts=""
for i in $*
do
	testcounts="${testcounts} $i"
done
errecho ${FUNCNAME} ${LINENO} "testcounts=${testcounts}" >&2
####################
# for each of the counts of the number of processes that will be used for
# testing, generate an 'srun' or 'mpirun' to run the ior test.
# Note that this script is highly specific to LLNL.  See MaxNodes above.
####################
for numprocs in ${testcounts}
do
	errecho ${FUNCNAME} ${LINENO} "numprocs=${numprocs}" >&2
	if [ ${numprocs} -eq 0 ]
	then
		####################
		# Nothing to do
		####################
		exit 0
	fi

	####################
	# Divide the number of processes for this test by the MinNodesDivisor
	# from the -p option to this script.  E.G. if you specify 10 processes
	# and a percentage of 50% (-p 50), then the MinNodesDivisor was set
	# to 100/50 -> 2, so that MinNodes would be set to 5
	####################
	((MinNodes=numprocs / MinNodesDivisor))
	((MinNodes+=(((numprocs%MinNodesDivisor>0)?1:0))))
#	errecho ${FUNCNAME} ${LINENO} "numprocs = ${numprocs}" >&2
#	errecho ${FUNCNAME} ${LINENO} "MinNodesDivisor = ${MinNodesDivisor}" >&2
#	errecho ${FUNCNAME} ${LINENO} "MinNodes = ${MinNodes}" >&2

	####################
	# If the user specified nodes manually (-N #), then you will use
	# that number (set above), otherwise we will set the number of srun_NODES
	#to the calculated MinNodes 
	####################
	if [ "${setnodes}" = "FALSE" ]
	then
		srun_NODES=${MinNodes}
	fi
	errecho ${FUNCNAME} ${LINENO} "srun_NODES=${srun_NODES}" >&2
	errecho ${FUNCNAME} ${LINENO} "numprocs=${numprocs}" >&2
	errecho ${FUNCNAME} ${LINENO} "MinNodesDivisor=${MinNodesDivisor}" >&2
	errecho ${FUNCNAME} ${LINENO} "MinNodes=${MinNodes}" >&2

	####################
	# This is a safety check to insure that the number of is not null or
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
#	errecho ${FUNCNAME} ${LINENO} "srun_NODES=${srun_NODES}" >&2
#	errecho ${FUNCNAME} ${LINENO} "MaxNodes=${MaxNodes}" >&2

	####################
	# Check to see if the user requested number of Nodes is greater than
	# the maximum nodes available on the machine under test.
	####################
	if [ ${srun_NODES} -gt ${MaxNodes} ]
	then
		errecho ${FUNCNAME} ${LINENO} \
			"Exceeded Maximum available nodes, Requested ${srun_NODES}, Max=${MaxNodes}" >&2
		exit 1
	fi

	####################
	# Encode the number of nodes and processes into zero prefixed strings
	# (E.G. 001 or 091) so that sort orders can be correct later.
	####################
	NODESTRING="$(printf "%03d" ${srun_NODES})"
	PROCSTRING="$(printf "%03d" ${numprocs})"

	####################
	# if the memory was limit to reduce caching effects, then add that to 
	# the name of the test.
	####################
	if [ ${memlimit} = "TRUE" ]
	then
		testnamesuffix="_MEM_${mempercent}"
	else
		testnamesuffix=""
	fi

	####################
	# Based on observed behavior on Corona, we will need approximately
	# one minute for each 100 processes to complete.  Let's modify the
	# user specified run time.
	#
	# We will build a small database to track the predicted vs. actual
	# time used by each band of 100, 200, 300 processes, etc. in a
	# small table.
	# 
	# We will use functions to get and set values in the database.
	# get_procrate returns the number of milliseconds per process
	# found in the table
	####################
	procrate_value=$(get_procrate "${iorbase}" "${fsbasename}" "${numprocs}")
	((milliseconds=procrate_value*numprocs))
	((one_ms_second=1000))
	((srun_time_seconds=milliseconds/one_ms_second))
	((srun_time_seconds+=(((milliseconds%one_ms_second>0)?1:0))))

	####################
	# This is purely defensive, there is no way that the number of seconds
	# should be zero if procrate_value was not zero
	####################
	if [ ${srun_time_seconds} -le 0 ]
	then
		errecho ${FUNCNAME} ${LINENO} "Invalid run time: srun_time_seconds=${srun_time_seconds}" >&2
		errecho ${FUNCNAME} ${LINENO} "procrate_value=${procrate_value}" >&2
		errecho ${FUNCNAME} ${LINENO} "numprocs=${numprocs}" >&2
		errecho ${FUNCNAME} ${LINENO} "milliseconds=${milliseconds}" >&2
		exit 1
	fi

	####################
	# Check if the number of seconds is more than 24 hours. If so, we need to
	# modify the time parameter to the srun/mpirun
	####################
	((dayseconds=24*60*60))
	if [ "${srun_time_seconds}" -ge ${dayseconds} ]
	then
		errecho ${FUNCNAME} ${LINENO} "Projected run time exceeds 24 hours, quitting" >&2
		exit 1
	fi

	####################
	# Note that this converts the number of seconds into HMS values.
	####################
	new_time=$(hmsout "${srun_time_seconds}" "seconds")
	errecho ${FUNCNAME} ${LINENO} "Adjusting time request to ${new_time}" >&2
	srun_time=${new_time}

	####################
	# The test suffix encodes the number of nodes, processes and requested
	# test time into the name of the test file where results are stored.
	####################
	testnamesuffix="${testnamesuffix}_N_${NODESTRING}_p_${PROCSTRING}_t_${srun_time}"

	####################
	# The test file is placed in the result directory.  The name of the file
	# is prefixed with 'ior' to distinguish it from mdtest ('md') or from 
	# macsio ('mac') testing
	####################
	iortestname="${iortestresultdir}/ior.${fsbasename}_${testnamesuffix}.txt"

	####################
	# echo out the name of the srun command that will be issued
	####################
	errecho ${FUNCNAME} ${LINENO} "ioropts=${ioropts}" >&2
 	echo "srun -n ${numprocs} -N ${srun_NODES} -t ${srun_time} ${iorexec} \
${ioropts} -o ${iorfilesystem}/$USER/ior.seq | \
tee -a ${iortestname}.txt" | tee -a ${iortestname}

	####################
	# If we are not just testing, the run the test.
	####################
	export IOR_TESTLOG=${iortestlog}
	if [ "${runner_testing}" = "FALSE" ]
	then
		date_began=$(date)

		$(logger "START" "${iorbase}" "$$" "${iorbatchstring}" "${iortestnumber}" "${fsbasename}" "${date_began}" "${numprocs}" "${srun_NODES}")
  	srun -n ${numprocs} -N ${srun_NODES} -t ${srun_time} ${iorexec} \
${ioropts} -o ${iorfilesystem}/$USER/ior.seq | \
tee -a ${iortestname}
		date_finished=$(date)
		$(logger "FINISH" "${iorbase}" "$$" "${iorbatchstring}" "${iortestnumber}" "${fsbasename}" "${date_finished}" "${numprocs}" "${srun_NODES}")
  	time_delta=$(date -d @$(( $(date -d "${date_finished}" +%s) - $(date -d "${date_began}" +%s) )) -u +'%H:%M:%S')
  	time_delta_seconds=$(date -d @$(( $(date -d "${date_finished}" +%s) - $(date -d "${date_began}" +%s) )) -u +'%s')
  	#time_delta_seconds=$(( $(date -d "${date_finished}" +%s) - $(date -d "${date_began}" +%s) ))
		$(logger "DELTA" "${iorbase}" "$$" "${iorbatchstring}" "${iortestnumber}" "${fsbasename}" "${time_delta}" "${time_delta_seconds}" "${numprocs}")
#		$(logger "RATE" "${iorbase}" "$$" "${iorbatchstring}" "${iortestnumber}" "${fsbasename}" "${time_delta}" "${numprocs}" $(func_introundup ${numprocs} 100) )
		echo $(setdefprocrate "${iorbase}" "$$" "${iorbatchstring}" "${iortestnumber}" "${fsbasename}" ${numprocs} "${time_delta_seconds}" "OBSERVED" ) > /dev/null
	fi
done
exit 0
# vim: set syntax=bash, ts=2, sw=2, lines=55, columns=120,colorcolumn=78
