#!/bin/bash
########################################################################
# Author: Robert E. Novak
# email: novak5@llnl.gov, sailnfool@gmail.com
#
# Set up Global variables for ior and mdtest benchmarks
# Define func_getlock and func_release to avoid conflicts
#
########################################################################
if [ -z "${__funcglobal}" ]
then
	export __funcglobal=1
	
	source func.errecho

	export IOR_HOMEDIR=$HOME/tasks/ior
	export INSTALLDIR=${IOR_HOMEDIR}/install.ior
	export BINDIR=${INSTALLDIR}/bin
	export IOR_EXEC=${IOR_BINDIR}/ior
	export IOR_BASE=${IOR_EXEC##*/}
	export IOR_UPPER=$(echo $IOR_BASE | tr [:lower:] [:upper:])
	export MD_EXEC=${BINDIR}/mdtest
	export MD_BASE=${MD_EXEC##*/}
	export MD_UPPER=$(echo ${MD_BASE} | tr [:lower:] [:upper:])
	export TESTDIR=${IOR_HOMEDIR}/testdir
	export ETCDIR=${TESTDIR}/etc
	export LOCKFILE=${ETCDIR}/lock
	export PROCRATE_SUFFIX=procrate.txt
	export PROCDEFAULT_SUFFIX=default.txt
	export PROCDEFAULT_TITLES="BAND|Default Hi Milliseconds Guess|Percentage Bump on Failure"
	export PROCRATE_TITLES="BAND|LO Milliseconds|HI Guessed Milliseconds|Guessed or Observed Data|HI Observed Milliseconds"
	export TESTLOG_SUFFIX=testlog.txt
	export TESTLOG=${ETCDIR}/${IOR_UPPER}.${TESTLOG_SUFFIX}
	export MD_TESTLOG=${ETCDIR}/${MD_UPPER}.${TESTLOG_SUFFIX}
	export PROCRATE_TMPFILE=${ETCDIR}/tmp.$$.${PROCRATE_SUFFIX}

	export PROC_BAND=100
	export DEFAULT_MS=700
	export FAIL_PERCENT=100
	export DEFAULT_STRING="${PROC_BAND}|${DEFAULT_MS}|${FAIL_PERCENT}"
	export LOCKERRS=${ETCDIR}/lockerrs
	export SRUNKILLSTRING="srun: Job step aborted: Waiting up to"


	####################
	# updating the following requires locking
	####################
	export TESTNUMBERFILE=${ETCDIR}/TESTNUMBER
	export BATCHNUMBERFILE=${ETCDIR}/BATCHNUMBER
	export IOR_METADATAFILE=${ETCDIR}/${IOR_UPPER}.VERSION.info.txt
	export MD_METADATAFILE=${ETCDIR}/${MD_UPPER}.VERSION.info.txt
	####################
	# End of files that need locking
	####################

	export one_ms_second=1000
	declare -A -g lo_ms
	declare -A -g hi_ms
	declare -A -g gobs
	declare -A -g obhi_ms

	func_getlock()
	{
		lockcount=0
		maxspins=10
		while [ -f ${LOCKFILE} ]
		do
			errecho ${FUNCNAME} ${LINENO} \
				"Sleeping on llock acquisition for lock owned by"
			errecho ${FUNCNAME} ${LINENO} \
				"$(ls -l ${LOCKFILE})"
			((++lockcount))
			if [ ${lockcount} -gt ${maxspins} ]
			then
				errecho ${FUNCNAME} ${LINENO} \
					"Exceeded ${maxspins} spins waiting for lock, quitting"
				exit 1
			fi
			sleep 1
		done
		touch ${LOCKFILE}
	}
	export -f func_getlock
	func_releaselock()
	{
		rm -f ${LOCKFILE}
	}
	export -f func_releaselock

	mkdir -p ${TESTDIR} ${ETCDIR}
	echo $(func_getlock) | sed '/^$/d' >> ${LOCKERRS}
	if [ ! -r ${TESTNUMBERFILE} ]
	then
		echo "0" > ${TESTNUMBERFILE}
	fi
	if [ ! -r ${BATCHNUMBERFILE} ]
	then
		echo "0" > ${BATCHNUMBERFILE}
	fi
	if [ ! -r  ${MD_TESTNUMBERFILE} ]
	then
		echo "0" > ${MD_TESTNUMBERFILE}
	fi
	echo $(func_releaselock)
fi # if [ -z "${__funcglobal}" ]
