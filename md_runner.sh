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
source func.global
source func.errecho
source func.insufficient
source func.logger
source func.arithmetic
source func.hmsout
source func.debug

USAGE="${0##*/} [-hdv] [-f <filesystem>] [-N #] -t <time> -x <partition> <#procs> ...\r\n
\t\trun the mdtest benchmark with default options\r\n
\t-h\t\tPrint this message\r\n
\t-v\t\tSet verbose mode. If set before -h you get verbose help\r\n
\t-a\t<opt>\tAdd options to the command line\r\n
\t-d\t#\tturn on diagnostics level #\r\n
\t-D\t#\tTurn on --posix.odirect\r\n
\t-f\t<filesystem>\trun mdtest against the named filesystem/\$USER\r\n
\t-N\t#\tthe number of nodes that you want to run on.\r\n
\t\tThis is a hard coded number. The numprocs will be distributed\r\n
\t\tacross this set of nodes.\r\n
\t\tIf not specified, it will be numprocs / processes per node\r\n
\t-o\t<opt>\treplace the default options with these\r\n
\t-p\t#\tthe number of processes per node\r\n
\t-s\t\tAssemble the requested runs as SBATCH scripts and place\r\n
\t\tin the BATCH directory\r\n
\t-t\t#\tthe number of minutes of CPU time you want to request\r\n
\t-x\t<partition>\tthe name of a partition (subset of nodes on\r\n
\t\tan MPI machine) (srun/sbatch dependent)\r\n"

VERBOSE_USAGE="${0##*/} Debugging, time information and default information\r\n
\t-d\t8\tTurns on the bash \"set -x\" flag.\r\n
\t-d\t6\tRuns this script in testing mode to show what would run\r\n
\t\t\tbut not actually run.\r\n
\t-f\t<fs>\tdefaults to a file system of /p/lustre3\r\n
\t-t\r<minutes>\tActually just passes through to srun. Defaults to\r\n
\t\t\tone minute.
\t\tThere is now a complex system that attempts to\r\n
\t\ttrack past usage to predict the number of milliseconds each\r\n
\t\tprocess will need to run.\r\n
\r\n
\t\t\tDefault Process Rate and Increase Percentage\r\n
\r\n
\t\tThe default tables are kept in the etc subdirectory of\r\n
\t\ttestdir and end in \*.default.txt  The prefix of the name is\r\n
\t\tthe uppercase name of the test (e.g., IOR) followed by\r\n
\t\tthe name of the file system under test. E.G.:\r\n
\r\n
\t\t\ttestdir/etc/IOR.lustre3.default.txt\r\n
\r\n
\t\tThe content of the file is three numbers separated by\r\n
\t\tvertical pipe \"|\" characters.  The first number is the\r\n
\t\tband of the number of processes.  E.G., 100 represents\r\n
\t\tthan this is used for 1 to 100 processes, 200 for 101-200\r\n
\t\tand so on.\r\n
\r\n
\t\tThe second number is a guess of the number of milliseconds\r\n
\t\teach process will need to run to completion. Don't worry\r\n
\t\tif your guess is too low or if you forget to enter this\r\n
\t\tfile at all.  If you do a default one is created.\r\n\r\n
\t\tThe third number is the percentage by which the\r\n
\t\tpreviously estimated time is increased if the benchmark\r\n
\t\tfailed due to exceeding estimated time.  A new GUESS\r\n
\t\trow is created with a larger estimate for the next run,\r\n
\r\n
\t\tA sample:\r\n
\r\n
\t\t\t100|300|20\r\n
\r\n
\t\t\tProcrate Table\r\n
\r\n
\t\tA process rate table keeps track of the GUESSED and\r\n
\t\tOBSERVED process rates for running the benchmark.\r\n
\t\tThe table is kept in:\r\n
\r\n
\t\ttestdir/etc/IOR.lustre3.procrate.txt\r\n
\r\n
\t\tThe procrate table contains 5 entries separated by \"|\"\r\n
\t\t\t1) The band of the number of processes that this tracks\r\n
\t\t\t     (as above), 100 represents 1-100 processes\r\n
\t\t\t2) The low GUESSED/OBSERVED milliseconds per process.\r\n
\t\t\t     This number is initially guessed at the same value as\r\n
\t\t\t     the HIGH miliseconds per process.  It is never increased\r\n
\t\t\t     by an OBSERVED value, only decreased.\r\n
\t\t\t3) The high number of milliseconds.  This value is only\r\n
\t\t\t     increased by either OBSERVED values or by a new GUESS.\r\n
\t\t\t4) OBSERVED/GUESS marks that this row was created by\r\n
\t\t\t     either an initial GUESS (see default.txt above) or by\r\n
\t\t\t     a replacement row where the GUESS high value is\r\n
\t\t\t     increased by the percentage in the default.txt table.\r\n
\t\t\t5) The lowest OBSERVED high value.  This always starts\r\n
\t\t\t     at zero (0) with a guess and keeps increasing.\r\n
\r\n
\t\tA sample: (assuming the prior run timed out!)\r\n
\r\n
\t\t\t100|250|10000|GUESS|7500\r\n
\r\n
\t\t\tBenchmark Run number\r\n
\r\n
\t\tThis script keeps a running count of how many times the script\r\n
\t\thas been run and uses that number in naming the directory in\r\n
\t\twhich the results are placed.  It uses a lock file to prevent\r\n
\t\tmultiple instances of the from updating the count\r\n
\t\tinconsistently.  If you see the script spinning on the lock\r\n
\t\tfile, you may have to kill the script and manually remove the\r\n
\t\tlock file from testdir\r\n
\r\n
\t\t\tBATCH Number\r\n
\r\n
\t\tIf the invoking script has defined the environment variable\r\n
\t\tbatchstring, then each benchmark run result will be\r\n
\t\tplace in a batch directory rather than standalone in\r\n
\t\ttestdir\r\n"


####################
# There must be at least one argument to this script which tells
# the number of processes to run for mdtest.
####################
runner_NUMARGS=1

####################
# debug flag for this script.
####################
runner_debug=${DEBUGOFF}

####################
# To expedite testing, we have a special bank on Corona
####################
srun_bank="vasttest"

####################
# Specify the default parallel file system under test in case the user
# forgets to specify one.
####################
filesystem=/p/lustre3/

####################
# Default options add with -a, override with -o
#
####################
#mdopts="-b 2 -z 3 -I 10 -i 5"
# variant opts from VAST
#default_options="-i 2 -I 256 -z 1 -b 64 -L -u -F"
default_options="-i 3 -F -C -T -r -w 0 -p 15 --posix.odirect"
new_options=""
add_options=""

####################
# This flag is set if we are only performing testing of the script
####################
runner_testing="FALSE"

####################
# This is the number of nodes that we will ask for from srun
# It is changed subject to MinNodesPercent and capped by MaxNodes
# Note that the -N option can override the above computation.
####################
srun_NODES="1"

####################
# this becomes true if the user selects a hard coded number of nodes
# in the script command line "-N"
####################
setnodes="FALSE"
processes_per_node=10

####################
# The default is to ask for 1 minute of run time from srun
# This script goes through computations to insure that it has
# an accurate estimate of the amount of time per process.
####################
srun_time=1

####################
# Turn on runner verbose mode to give more complete help
####################
runner_verbose="FALSE"
export FUNC_VERBOSE=0

####################
# Added an -x command line option to specify an alternate partition
# the names of the partitions come from the 'scontrol' command
#
# The default is to use the default partion so the setpartion
# flag is set to "FALSE"  If the user specifies a partition:
# -x mi25
# then mi25 will be provided to srun as the selected partition
####################
setpartition="FALSE"

####################
# These are the getopt flags processed by mdrunner.  They are hopefully
# adequately understandable from the (-h) flag.
####################
runner_optionargs="hsva:t:d:f:p:N:o:x:"

while getopts ${runner_optionargs} name
do
	case $name in
		a)  # Add options to the benchmark default list
			add_options="${OPTARG}"
			;;
		d)	# Debugging
			FUNC_VERBOSE="${OPTARG}" # see func.errecho
			runner_debug="${OPTARG}"
			if [ "${runner_debug}" -ge "${DEBUGSETX}" ]
			then
				set -x
			fi
			if [ "${runner_debug}" -ge "${DEBUGNOEXECUTE}" ]
			then
				runner_testing="TRUE"
			fi
			;;
		f)	# Fileystem
			filesystem="${OPTARG}"
			;;
    h)	# Help
			echo -en "${USAGE}"
			if [ "${runner_verbose}" = "TRUE" ]
			then
				echo -en "${VERBOSE_USAGE}"
			fi
			exit 0
			;;
		N)	# Number of Nodes FIXED, not calculated
			if [[ ! "${OPTARG}" =~ -?[0-9]+ ]]
			then
				errecho ${LINENO} "You must specify a numeric argument for -N"
				echo -en "${USAGE}"
				exit 1
			fi
			srun_NODES="${OPTARG}"
			setnodes="TRUE"
			;;
		o)	# replace default options for mdtest
			new_options="${OPTARG}"
			;;
		p)	# number of processes per node
			if [[ ! "${OPTARG}" =~ -?[0-9]+ ]]
			then
				errecho ${LINENO} "You must specify a numeric argument for -p"
				echo -en "${USAGE}"
				exit 1
			fi
			processes_per_node=${OPTARG}
			;;
		s)
			wantSBATCH="TRUE"
			;;
		t)	# time specification.  Should be checked with a
				# regular expression that accepts a number or a time
				# specification in HH:MM:SS
			srun_time="${OPTARG}"
			;;
		v)	# Verbose mode
			runner_verbose="TRUE"
			;;
		x) # use to specify a partition other than the default
			setpartition="TRUE"
			partitionname="${OPTARG}"
			;;
		\?)	# Invalid
			errecho "-e" ${LINENO} "invalid option: -$OPTARG"
			errecho "-e" ${LINENO} "${USAGE}"
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
	errecho "-e" "${0##*/}" ${LINENO} \
		"You must provide at least one argument that describes\r\n
the number of processes you want to run for testing\r\n"
	errecho "-e" "${0##*/}" ${LINENO} "${USAGE}"
	insufficient "${0##*/}" ${LINENO} "${runner_NUMARGS}" "$@"
fi

####################
# Collect the time we start the script to use as part of the name
# of the directory where the results are collected.
####################
starttime=$(date "+%Y%m%d.%H%M%S")


####################
# Create a lock file so that two different scripts don't update the test
# number
####################
func_getlock | sed '/^$/d' | tee -a "${LOCKERRS}"

####################
# if it does not exist, initialize it with a zero value
####################
if [ ! -f "${TESTNUMBERFILE}" ]
then
	echo 0 > "${TESTNUMBERFILE}"
fi

####################
# retrieve the number in the file.
####################
testnumber=$(cat "${TESTNUMBERFILE}" )

####################
# bump the test number and stuff it back in the file.
# I need testing to make sure that I can eliminate the echo
####################
((++testnumber))>/dev/null
echo "${testnumber}" > "${TESTNUMBERFILE}"

####################
# Now we can release the lock
####################
func_releaselock | sed '/^$/d' | tee -a "${LOCKERRS}"

####################
# Retrieve the current MD testnumber and stuff it in a zero prefixed
# string to identify the current results directory
####################
teststring="${USER}-$(printf '%04d' ${testnumber})"

####################
# If we are invoked as a batch of runs, then the caller will set
# a batchstring that we can use as the directory name for the batch
# that we are part of.  If they did not set this, it is a null string.
# This takes advantage of the fact taht all directory/file parsing
# in both Unix and Linux collapses // to /
# If this is passes as a parameter to a sub-shell or function it
# should always be placed in "" to avoid mismatched parameter counts
####################
batchstring=${batchstring:=""}

####################
# This is the name of the directory where all of the results from this
# batch of runs will be placed.
# In this same directory, we will place the directives file (if used)
# and the information about the version of IOR that is under test.
####################
x="${TESTDIR}/${batchstring}/${starttime}_${teststring}"
testresultdir="${x}"
mkdir -p "${testresultdir}"

####################
# Get the date that the executable was built and the
# version string embedded in the binary
# store this information in the testresultdirectory in a file called
# VERSION_info.txt
####################
iorbuilddate=$(sourcedate -t "${INSTALLDIR}" )

func_getlock | sed '/^$/d' | tee -a "${LOCKERRS}"
echo "mdtest Build Date information" >> "${MD_METADATAFILE}"
echo "${iorbuilddate}" >> "${MD_METADATAFILE}"
func_releaselock | sed '/^$/d' | tee -a "${LOCKERRS}"

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
#
# The same parsing should be done to insure that the specified
# partition in the -x option (if specified) exists, although there
# is really no need to protect the user from themselves.
####################
which srun > /dev/null
found_srun=$?
if [ "${found_srun}" -eq "0" ]
then
	MaxNodes=$(scontrol show partition | \
		sed -n -e '/MaxNodes/s/^[ ]*MaxNodes=\([^ 	]*\).*/\1/p' | tail -1)
else
	errecho "${0##*/}" ${LINENO} \
		"Could not find srun on this machine"
	errecho "${0##*/}" ${LINENO} \
		"Are you sure you are on the right machine?"
	errecho "${0##*/}" ${LINENO} \
		"If you need to run mpirun. fix the code here"
	exit 1
fi

####################
# get the basename of the filesystem under test
####################
fsbase=${filesystem##*/}
if [[ "${fsbase}" =~ lustre[1-3] ]]
then
	BIN_MD=${LUSTRE_MD_EXEC}
else
	BIN_MD=${MD_EXEC}
fi

####################
# sanity check to make sure that the file sytem exists
####################
if [ ! -d "${filesystem}" ]
then
	errecho "${0##*/}" ${LINENO} \
		"Could not detect filesystem (-f) = ${filesystem}"
	errecho -e "${0##*/}" ${LINENO} "${USAGE}"
	exit 1
fi
func_getlock | sed '/^$/d' | tee -a "${LOCKERRS}"
mount | grep "${fsbase}" >> "${MD_METADATAFILE}"
func_releaselock | sed '/^$/d' | tee -a "${LOCKERRS}"

####################
# Standard options we don't override
####################
if [ ! -z "${add_options}" ]
then
	default_options="${default_options} ${add_options}"
fi
if [ ! -z "${new_options}" ]
then
	default_options="${new_options}"
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

	if [ "${numprocs}" -eq 0 ]
	then
		###################
		# Nothing to do
		###################
		exit 0
	fi

	####################
	# If the user specified nodes manually (-N #), then you will use
	# that number (set above), otherwise we will set the number of
	# srun_NODES to the calculated MinNodes
	####################
	if [ "${setnodes}" = "FALSE" ]
	then
		((srun_NODES=numprocs/processes_per_node))
	else
		((processes_per_node=numprocs/srun_NODES))
	fi
  	errecho "${0##*/}" ${LINENO} "srun_NODES=${srun_NODES}"

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
#  	errecho "${0##*/}" ${LINENO} "srun_NODES=${srun_NODES}"
#  	errecho "${0##*/}" ${LINENO} "MaxNodes=${MaxNodes}"

	####################
	# Check to see if the user requested number of Nodes is greater than
	# the maximum nodes available on the machine under test.
	####################
	if [ "${srun_NODES}" -gt "${MaxNodes}" ]
	then
		errecho "${0##*/}" ${LINENO} \
			"Exceeded Maximum available nodes\r\n
Requested ${srun_NODES}, Max=${MaxNodes}\r\n" >&2
		exit 1
	fi

	####################
	# Encode the number of nodes and processes into zero prefixed strings
	# (E.G. 001 or 091) so that sort orders can be correct later.
	####################
	NODESTRING="$(printf "%03d" ${srun_NODES})"
	PROCSTRING="$(printf "%03d" \"${numprocs}\")"

	####################
	# Based on observed behavior, we will need to modify the amount
	# of time specified to run a set of processes.  The following
	# sections of code are designed to accomplish two things:
	# 1) Specify a default amount of milliseconds per process for
	#    each group of 100 processes.  This default is used for
	#    populating the table which suggests the number of milliseconds
	#    per process based on groups or "bands" of 100 processes, E.G.
	#    100 processes, 200 processes and so on.
	# 2) The second is to specify the percentage amount by which to
	#    increase the time that came from prior estimates (GUESS)
	#    or observations (OBSERVED) in the event that the run command
	#    fails (srun or mpirun) and cancels the launced processes for
	#    exceeding their time limit.
	#
	# If there is no table (look at the name of the file in func.global)
	# then we push in hard coded defaults.  These are unlikely to be
	# adequate defaults.  However, if the user hand edited the table,
	# then those values will be used.
	#
	# More on the banding table in a moment.
	####################
	fileprefix=${MD_UPPER}.${fsbase}

	procdefault_file=${ETCDIR}/${fileprefix}.${PROCDEFAULT_SUFFIX}

	if [ ! -r "${procdefault_file}" ]
	then
		errecho "${0##*/}" ${LINENO} "File Not Found ${procdefault_file}"
		errecho "${0##*/}" ${LINENO} \
			"Need a Default Band (e.g. 100 processes, default millisconds"
		errecho "${0##*/}" ${LINENO} \
			"per process and the amount by which to increase guess times"
		errecho "${0##*/}" ${LINENO} \
			"after failures"

		####################
		# Instead of exiting we could emit a default file here
		####################
		func_getlock | sed '/^$/d' | tee -a "${LOCKERRS}"
		echo "${PROCDEFAULT_TITLES}" > "${procdefault_file}"
		echo "${DEFAULT_STRING}" >> "${procdefault_file}"
		func_releaselock | sed '/^$/d' | tee -a "${LOCKERRS}"
	fi # if [ ! -r ${procdefault_file} ]

	linesread=0
	OLDIFS=$IFS
	IFS="|"

	while read -r band default percent
	do
		####################
		# Skip the title line
		####################
		if [ ! "$band" = "BAND" ]
		then
			export PROC_BAND=${band}
			export DEFAULT_MS=${default}
			export FAIL_PERCENT=${percent}
		fi
		((++linesread))
	done < "${procdefault_file}"
	IFS=$OLDIFS

	####################
	# We have to read a header line and one content line
	####################
	if [ ${linesread} -lt 2 ]
	then
		errecho "${0##*/}" ${LINENO} \
			"Could not read ${procdefault_file}"
		exit 1
	fi

	####################
	# We will build a small database to track the predicted vs. actual
	# time used by each band of 100, 200, 300 processes, etc. in a
	# small table.
	#
	# Note that if the process rate table (procrate) does not exist
	# then we will create a one row table for 100 processes using
	# the information from the default table (either created above)
	# or modified by the user.  Since we don't have data, this
	# is marked as a GUESS.
	####################
	procrate_file=${ETCDIR}/${fileprefix}.${PROCRATE_SUFFIX}
	changed_procrate_file="FALSE"

	if [ ! -r "${procrate_file}" ]
	then
		errecho "${0##*/}" ${LINENO} \
			"File Not found ${procrate_file}"
		errecho "${0##*/}" ${LINENO} \
			"Creating a two line default table"
		echo "${PROCRATE_TITLES}" > "${procrate_file}"
		echo "100|${DEFAULT_MS}|${DEFAULT_MS}|GUESS|0" >> "${procrate_file}"
		changed_procrate_file="FALSE"
	fi

	linesread=0
	OLDIFS=$IFS
	IFS="|"

	while read -r band low high gob obhigh
	do
		((++linesread))
		if [ ! "$band" = "BAND" ]
		then
			lo_ms[$band]=$low
			hi_ms[$band]=$high
			gobs[$band]=$gob
			obhi_ms[$band]=$obhigh
		fi
	done < "${procrate_file}"
	IFS=$OLDIFS

	####################
	# If we did not get any data out of the procrate file, quit
	# Must get the title line and one data line
	####################
	if [ ${linesread} -lt 2 ]
	then
		errecho "${0##*/}" ${LINENO} \
			"Could not read ${procrate_file}"
		exit 1
	else
		changed_procrate_file="TRUE"
	fi

	####################
	# since at this point we know how many processes the user
	# wants to run, we will select a row (band) from the procrate
	# table.  We simply roundup the number of processes to the next
	# higher multiple of PROC_BAND
	####################
	band=$(func_introundup "${numprocs}" "${PROC_BAND}")
	
	####################
	# If there is no existing table entry for this band, then we
	# will create a new GUESS row using the DEFAULT values
	####################

	if [ ! "${hi_ms[${band}]+_}" ]
	then
		lo_ms[${band}]=${DEFAULT_MS}
		hi_ms[${band}]=${DEFAULT_MS}
		gobs[${band}]="GUESS"
		obhi_ms[$band]=0
		changed_procrate_file="TRUE"
	fi

	errecho "${0##*/}" ${LINENO} "hi_ms[$band]=${hi_ms[$band]}"

	((milliseconds=hi_ms[$band]*numprocs))
	((srun_time_seconds=milliseconds/one_ms_second))
	((srun_time_second+=(((milliseconds%one_ms_second>0)?1:0))))

	####################
	# This is purely defensive, there is no way that the number of
  # seconds should be zero if hi_ms[$band] was not zero
	####################
	if [ ${srun_time_seconds} -le 0 ]
	then
		errecho "${0##*/}" ${LINENO} \
      "Invalid run time: srun_time_seconds=${srun_time_seconds}" >&2
		errecho "${0##*/}" ${LINENO} \
      "hi_ms[$band]=${hi_ms[$band]}" >&2
		errecho "${0##*/}" ${LINENO} \
      "numprocs=${numprocs}" >&2
		errecho "${0##*/}" ${LINENO} \
      "milliseconds=${milliseconds}" >&2
		exit 1
	fi

	####################
	# Check if the number of seconds is more than 16 hours. If so, we
	# need to modify the time parameter to the srun/mpirun
	####################
  maxhours=16
	((max_srun_time=maxhours*60*60))
	if [ "${srun_time_seconds}" -ge ${max_srun_time} ]
	then
		errecho "${0##*/}" ${LINENO} \
			"Projected run time exceeds ${maxhours} hours, Adjusting"
    ((srun_time_seconds=max_srun_time-1))
	fi

	####################
	# Note that this converts the number of seconds into HMS values.
	####################
	new_time=$(hmsout "${srun_time_seconds}" "seconds")
	errecho "${0##*/}" ${LINENO} "Adjusting time request to ${new_time}"
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
x="${testresultdir}/${MD_UPPER}.${fsbase}_${testnamesuffix}.txt"
	mdtestname="${x}"

	####################
	# Cleanup from prior runs (Specific recovery to mdtest)
	####################
	md_cleanup ${filesystem}
	if [ $? -ne 0 ]
	then
		exit 1
	fi
	dirhead=${filesystem}/${USER}/md.seq.$$
	####################
	# Check to see if we want to run in a different partion.
	####################
	if [ "${setpartition}" = "TRUE" ]
	then
		partitionopt="-p ${partitionname}"
	else
		partitionopt=""
	fi

	####################
	# echo out the name of the srun command that will be issued
	####################
	command_date_began=$(date)
	command_line="srun -A ${srun_bank} ${partitionopt} -n ${numprocs} \
-N ${srun_NODES} -t ${srun_time} \
${BIN_MD} ${default_options} -d ${dirhead} 2>&1 | \
tee -a ${mdtestname}"
	echo "COMMAND|${command_date_began}|${command_line}" | \
		tee -a "${TESTLOG}"

	if [ "${wantSBATCH}" = "TRUE" ]
	then
		sbatchfile=${testresultdir}/sbatch_${teststring}.sh
    rm -f "${sbatchfile}"
    {
	  	echo "#!/bin/bash"
		  echo "######## These Lines are for Slurm" 
		  echo "#SBATCH -N ${srun_NODES}" 
		  echo "#SBATCH -n ${numprocs}" 
		  echo "#SBATCH -A ${srun_bank}" 
		  echo "#SBATCH -J ${teststring}" 
		  echo "#SBATCH -t ${srun_time}" 
    } >> "${sbatchfile}"
		if [ ! -z "${partitionopt}" ]
		then
			echo "#SBATCH ${partitionopt}" >> "${sbatchfile}"
		fi
    {
		  echo "#SBATCH -o /p/lustre3/${USER}/${teststring}.txt" 
		  echo "#SBATCH -D /p/lustre3/${USER}" 
		  echo "#SBATCH --license=${fsbase}" 
		  echo "#SBATCH --mail-type=all" 
		  echo "command_date_began=\$(date)" 
    } >> "${sbatchfile}"
		batch_command="srun ${BIN_MD} ${default_options}
-o ${filesystem}/$USER/ior.seq 2>&1 | tee -a ${mdtestname} "
		echo "echo COMMAND|${command_date_began}|${batch_command} |  \
			tee -a ${TESTLOG}" >> "${sbatchfile}"
		echo "${batch_command}" >> "${sbatchfile}"
	fi


	####################
	# If we are not just testing, then run the test.
	####################
	if [ "${runner_testing}" = "FALSE" ]
	then
		date_began=$(date)

		####################
		# Log the START
		####################
		logger "START" "${MD_BASE}" "$$" "${batchstring}" \
"${testnumber}" "${fsbase}" "${date_began}" "${numprocs}" \
"${srun_NODES}"

		####################
		# Run the benchmark test
		####################
		echo "${command_line}"
		if [ "${runner_strace}" = "FALSE" ]
		then
			echo "${command_line}" | bash
		else
			echo strace -o${sbatchfile}.strace "${command_line}" | bash
			cat ${sbatchfile}.strace >> "${sbatchfile}"
		fi

#		srun ${partitionopt} -n "${numprocs}" -N "${srun_NODES}" \
#-t "${srun_time}" \
#"${BIN_MD}" ${default_options} -d ${dirhead} 2>&1 | \
#tee -a "${mdtestname}"

if [[ $(grep -c "${SRUNKILLSTRING}" "${mdtestname}") == "1" ]]
		then
			srun_status=1
		else
			srun_status=0
		fi

		####################
		# We grep for the error message that srun was killed as a
		# primary indicator that the benchmark is
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
			oldtime=${hi_ms[$band]}
			((hi_ms[$band]+=(${hi_ms[$band]}*FAIL_PERCENT)/100))
			errecho "${0##*/}" ${LINENO} \
				"FAILURE: oldtime=${oldtime}, newtime=${hi_ms[$band]}"
			echo "COMMAND_FAILED|${command_date_began}|${command_line}" | \
				tee -a "${TESTLOG}"

			####################
			# Following a failure we don't have true observed time. As
			# a result, we have to mark this increased amount of time as
			# a guess.
			####################
			gobs[$band]=GUESS
			obhi_ms[$band]=0
			lo_ms[$band]=${hi_ms[$band]}

			####################
			# Save the old file in the event of failure
			####################
			cp "${procrate_file}"  "${procrate_file}.old.txt"
			
			####################
			# We remove the current file and write a new one dumped from
			# the Associative array where we keep the data.
			####################
			rm -f "${procrate_file}"
			for band in "${!lo_ms[@]}"
			do
				if [ -z "${obhi_ms[$band]}" ]
				then
					obhi_ms[$band]=0
				fi
				echo  \
			"${band}|${lo_ms[${band}]}|${hi_ms[${band}]}|${gobs[${band}]}|${obhi_ms[${band}]}" \
					>> "${PROCRATE_TMPFILE}"
			done
			echo "${PROCRATE_TITLES}" > "${procrate_file}"
			sort -u -n -t "|" "${PROCRATE_TMPFILE}" >> "${procrate_file}"
			rm -f "${PROCRATE_TMPFILE}"
			changed_procrate_file="FALSE"

		else # if [ $srun_status -ne 0 ]

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
		logger "FINISH" "${MD_BASE}" "$$" "${batchstring}" \
"${testnumber}" "${fsbase}" "${date_finished}" "${numprocs}" \
"${srun_NODES}" "${completion}"
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
		logger "DELTA" "${MD_BASE}" "$$" "${batchstring}" \
"${testnumber}" "${fsbase}" "${time_delta}" "${time_delta_seconds}" \
"${numprocs}" "${lo_ms[$band]}" "${hi_ms[$band]}" "${completion}"

		####################
		# Record the new rate in the procrate table
		# We compute the number of milliseconds/process rounding up
		####################
		((new_ms=(time_delta_seconds*one_ms_second)/numprocs))
		((new_ms+=((time_delta_seconds*one_ms_second)%numprocs>0)?1:0))

		####################
		# if we have reached a new high for this band, update the high
		####################
		changed_procrate_file="FALSE"
		if [ ! -z "${obhi_ms[$band]}" ]
		then
			if [ ${new_ms} -gt ${obhi_ms[$band]} ]
			then
				obhi_ms[$band]=${new_ms}
				changed_procrate_file="TRUE"
			fi
		else
			obhi_ms[$band]=0
			changed_procrate_file="TRUE"
		fi
		if [ "${new_ms}" -gt "${hi_ms[$band]}" ]
		then
			hi_ms[$band]=${new_ms}
			gobs[$band]="OBSERVED"
			changed_procrate_file="TRUE"
		else
			####################
			# if we have reached a new low for this band, update the low
			# if the new time is zero it must be an artifact of a failure
			# don't allow it to show up as the low time
			####################
			if [ "${new_ms}" -ne 0 ]
			then
				if [ "${new_ms}" -lt "${lo_ms[$band]}" ]
				then
					lo_ms[$band]=${new_ms}
					gobs[$band]="OBSERVED"
					changed_procrate_file="TRUE"
				fi
			fi
		fi
		####################
		# if the table changed, then save it.
		####################
		if [ "${changed_procrate_file}" = "TRUE" ]
		then
			rm -f "${procrate_file}"
			for band in "${!lo_ms[@]}"
			do
				if [ -z "${obhi_ms[$band]}" ]
				then
					obhi_ms[$band]=0
				fi
				echo  \
			"${band}|${lo_ms[${band}]}|${hi_ms[${band}]}|${gobs[${band}]}|${obhi_ms[${band}]}" \
					>> "${PROCRATE_TMPFILE}"
			done
			echo "${PROCRATE_TITLES}" > "${procrate_file}"
			sort -u -n -t "|" "${PROCRATE_TMPFILE}" >> "${procrate_file}"
			rm -f "${PROCRATE_TMPFILE}"
			changed_procrate_file="FALSE"
		fi
	
		####################
		# Now we log the rate from this
		####################
		logger "RATE" "${MD_UPPER}" "$$" "${batchstring}" \
"${testnumber}" "${fsbase}" "${srun_time}" "${numprocs}" \
"${band}" "${new_ms}" "${lo_ms[$band]}" "${hi_ms[$band]}"
	fi
done

if [ "${wantSBATCH}" = "TRUE" ]
then
	if [ "${runner_testing}" = "FALSE" ]
	then
		for sbatch_script in ${testresultdir}/sbatch_*.sh
		do
			bash "${sbatch_script}"
		done
	fi
fi

rm -f "${procrate_file}.old.txt" "${PROCRATE_TMPFILE}"
exit 0
# vim: set syntax=bash, ts=2, sw=2, lines=55, columns=120,colorcolumn=78
