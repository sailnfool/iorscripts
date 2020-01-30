#!/bin/bash   
################################################################################
# Author: Robert E. Novak
# email: novak5@llnl.gov, sailnfool@gmail.com
#
# Run the mdtest (metadata test) script repeatedly across a set of
# processees that can be distributed across nodes.
#
################################################################################
source func.errecho
source func.insufficient
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
runner_NUMARGS=0

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
# These are the getopt flags processed by mdrunner.  They are hopefully
# adequately understandable from the (-h) flag.
####################
runner_optionargs="hvt:d:f:p:N:"

while getopts ${runner_optionargs} name
do
	case $name in
    h)
			echo -en ${USAGE}
			if [ "${runner_verbose}" = "TRUE" ]
			then
				echo -en ${VERBOSE_USAGE}
			fi
			exit 0
			;;
		d)
			FUNC_DEBUG=${OPTARG} # see func.errecho
			runner_debug=${OPTARG}
			if [ ${runner_debug} -ge 9 ]
			then
				set -x
			fi
			if [ ${runner_debug} -ge 6 ]
			then
				runner_testing=TRUE
			fi
			;;
		v)
			runner_verbose=TRUE
			;;
		f)
			filesystem=${OPTARG}
			;;
		p)
			((MinNodesDivisor= 100 / OPTARG))
			;;
		N)
			srun_NODES=${OPTARG}
			setnodes=TRUE
			;;
		t)
			srun_time=${OPTARG}
			;;
		\?)
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
	exit 1
fi

####################
# Collect the time we start the script to use as part of the name of the 
# directory where the results are collected.
####################
starttime=$(date -u "+%Y%m%d.%H%M%S")

####################
# when we built mdtest, it was placed in a directory relative to the
# home directory as part of ior.
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

####################
# we will place the testing directory at the same level as the installation
# directory, not as a subset of the installation.
####################
iortestdir=${iorinstalldir}/../testdir

####################
# If the test directory is not yet created, then make it.
####################
if [ ! -d ${iortestdir} ]
then
	mkdir -p ${iortestdir}
fi
####################
# Create a lock file so that two different scripts don't update the test
# number
####################
while [ -f ${iortestdir}/lock ]
do
	errecho ${LINENO} "Sleeping on lock acquistion for lock owned by"
	errecho ${LINENO} "$(ls -l ${iortestdir}/lock*)"
	sleep 1
done
touch ${iortestdir}/lock
touch ${iortestdir}/lock_process_${USER}_$$

####################
# Use a file to keep track of the number of tests that have been run by this 
# script against the executable.
####################
mdtestnumberfile=${iortestdir}/MD.TESTNUMBER

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
####################
((++mdtestnumber))
echo ${mdtestnumber} > ${mdtestnumberfile}

####################
# retrieve the current test number and stuff it in a test string for
# identifying the results directory
####################
mdteststring="${USER}-$(printf '%04d' ${mdtestnumber})"

####################
# Now we can release the lock and the lock info
####################
rm -f ${iortestdir}/lock_process_${USER}_$$
rm -f ${iortestdir}/lock

####################
# If we are invoked as a batch of runs, then the caller will set
# a batchstring that we can use as the directory name for the batch
# that we are part of.  If they did not set this, it is a null string.
# This takes advantage of the fact taht all directory/file parsing
# in both Unix and Linux collapses // to /
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
mdmetadatafile=${mdtestresultdir}/mdtestVERSION_info.txt
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
# there is a moderate amount of parsting to figure out which is the 
# default partition.  We are punting on that for now.
####################
MaxNodes=$(scontrol show partition | \
	sed -n -e '/MaxNodes/s/^[ ]*MaxNodes=\([^ 	]*\).*/\1/p' | tail -1)

####################
# get the basename of the filesystem under test
####################
filesystembasename=${filesystem##*/}

####################
# sanity check to make sure that the file sytem exists
####################
if [ ! -d ${filesystem} ]
then
	errecho ${LINENO} "Could not detect filesystem (-f) = ${filesystem}"
	errecho -e ${LINENO} ${USAGE}
	exit 1
fi

####################
# Standard options we don't override
####################
mdopts="-b 2 -z 3 -I 10 -i 5"

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

	####################
	# Divide the number of processes for this test by the MinNodesDivisor
	# from the -p option to this script.  E.G. if you specify 10 processes
	# and a percentage of 50% (-p 50), then the MinNodesDivisor was set
	# to 100/50 -> 2, so that MinNodes would be set to 5
	####################
	((MinNodes=numprocs / MinNodesDivisor))
	errecho ${LINENO} "numprocs = ${numprocs}"
	errecho ${LINENO} "MinNodesDivisor = ${MinNodesDivisor}"
	errecho ${LINENO} "MinNodes = ${MinNodes}"
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
	errecho ${LINENO} "srun_NODES=${srun_NODES}"

	####################
	# This is a safety check to insure that the number of NODES is nota
	# null or zero.  We could exit at this point if either of these is true.
	####################
	if [ -z "${srun_NODES}" ]
	then
		srun_NODES=1
	fi
	if [ ${srun_NODES} -eq 0 ]
	then
		srun_NODES=1
	fi
	errecho ${LINENO} "srun_NODES=${srun_NODES}"
	errecho ${LINENO} "MaxNodes=${MaxNodes}"

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
	# Watch this carefully, it is more likely to be per 50 processes
	####################
	ppmfile=${iortestdir}/MD.${filesystembasename}.procs_per_minute
	if [ -r ${ppmfile} ]
	then
		procs_per_minute=$(cat ${ppmfile})
	else
		procs_per_minute=100
		echo 100 > ${ppmfile}
	fi
	errecho ${LINENO} "procs_per_minute = ${procs_per_minute}"
	((new_time = numprocs / procs_per_minute))
	((new_time += ( ((numprocs % procs_per_minute))>0)?1:0))
	errecho ${LINENO} "Adjusting time request to ${new_time} minutes"
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
	mdtestname="${mdtestresultdir}/md.${filesystembasename}_${testnamesuffix}"

	####################
	# echo out the name of the srun command that will be issued
	####################
	dirhead=${filesystem}/$USER/md.seq
	if [ -d ${dirhead} ]
	then
		echo "$(find ${dirhead} -type d -print | wc -l) directories left over"
		echo "$(find ${dirhead} -type f -print | wc -l) files left over"
		time rm -rf ${dirhead}
	fi
 	echo "srun -n ${numprocs} -N ${srun_NODES} -t ${srun_time} ${mdexec} \
${mdopts} -d ${filesystem}/$USER/md.seq | \
tee -a ${mdtestname}.txt" | tee -a ${mdtestname}.txt

	####################
	# If we are not just testing, the run the test.
	####################
	mdtestlog=${iortestdir}/MD.test.log
	if [ "${runner_testing}" = "FALSE" ]
	then
		date_began=$(date)
		echo "START|mdtest|${filesystembasename}|${mdbatchstring}|${date_began}|${numprocs}|${srun_NODES}" >> ${mdtestlog}
  	srun -n ${numprocs} -N ${srun_NODES} -t ${srun_time} ${mdexec} \
${mdopts} -d ${filesystem}/$USER/md.seq | \
tee -a ${mdtestname}.txt
		date_finished=$(date)
		echo "FINISH|mdtest|${filesystembasename}|${mdbatchstring}|$(date)|${numprocs}|${srun_NODES}" >> ${mdtestlog}
  	time_delta=$(date -d @$(( $(date -d "${date_finished}" +%s) - $(date -d "${date_began}" +%s) )) -u +'%H:%M:%S')
  	time_delta_seconds="$(( $(date -d "${date_finished}" +%s) - $(date -d "${date_began}" +%s) ))"
		echo "DELTA|mdtest|${filesystembasename}|${mdbatchstring}|${time_delta}|${time_delta_seconds}|${numprocs}" >> ${mdtestlog}
		((time_delta_minutes = time_delta_seconds / 60))
		if [ ${time_delta_minutes} -eq 0 ]
		then
			rate_per_minute=${procs_per_minute}
		else
			((rate_per_minute = numprocs / time_delta_minutes))
			((rate_per_minute += ( ((numprocs % time_delta_minutes))>0)?1:0))
		fi
		errecho ${LINENO} "rate_per_minute=${rate_per_minute}"
		echo "RATE|mdtest|${filesystembasename}|${mdbatchstring}|${rate_per_minute}" >> ${mdtestlog}
		if [ ${rate_per_minute} -eq 0 ]
		then
			errecho ${LINENO} "ZERO RATE PER MINUTE - Re think the process"
			errecho ${LINENO} "$(tail -4 ${mdtestlog})"
			errecho ${LINENO} "Current PPM for ${filesystembasename} = $(cat ${ppmfile})"
			exit 1
		fi
		if [ ${rate_per_minute} -lt ${procs_per_minute} ]
		then
			echo ${rate_per_minute} > ${ppmfile}
		fi
	fi
done
exit 0
