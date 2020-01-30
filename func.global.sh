#!/bin/bash
if [ -z "${__funcglobal}" ]
then
	export __funcglobal=1
	
	source func.errecho

	export IOR_HOMEDIR=$HOME/tasks/ior
	export IOR_INSTALLDIR=${IOR_HOMEDIR}/install.ior
	export IOR_BINDIR=${IOR_INSTALLDIR}/bin
	export IOR_EXEC=${IOR_BINDIR}/ior
	export IOR_BASE=${IOR_EXEC##*/}
	export IOR_UPPER=$(echo $IOR_BASE | tr [:lower:] [:upper:])
	export MD_EXEC=${IOR_BINDIR}/mdtest
	export MD_BASE=${MD_EXEC##*/}
	export MD_UPPER=$(echo ${MD_BASE} | tr [:lower:] [:upper:])
	export IOR_TESTDIR=${IOR_HOMEDIR}/testdir
	export IOR_ETCDIR=${IOR_TESTDIR}/etc
	export IOR_LOCKFILE=${IOR_ETCDIR}/lock
	export PROCRATE_SUFFIX=procrate.txt
	export PROCRATEMIN_SUFFIX=default.txt
	export PROCBAND_SUFFIX=procband.txt
	export TESTLOG_SUFFIX=testlog.txt
	export IOR_TESTLOG=${IOR_ETCDIR}/${IOR_UPPER}.${TESTLOG_SUFFIX}
	export MD_TESTLOG=${IOR_ETCDIR}/${MD_UPPER}.${TESTLOG_SUFFIX}

	####################
	# updating the following requires locking
	####################
	export IOR_TESTNUMBERFILE=${IOR_ETCDIR}/${IOR_UPPER}.TESTNUMBER
	export MD_TESTNUMBERFILE=${IOR_ETCDIR}/${MD_UPPER}.TESTNUMBER
	export IOR_BATCHNUMBERFILE=${IOR_ETCDIR}/${IOR_UPPER}.BATCHNUMBER
	export IOR_METADATAFILE=${IOR_ETCDIR}/${IOR_UPPER}.VERSION.info.txt
	export MD_METADATAFILE=${IOR_ETCDIR}/${MD_UPPER}.VERSION.info.txt
	####################
	# End of files that need locking
	####################

	export one_ms_second=1000

	func_getlock()
	{
		lockcount=0
		maxspins=10
		while [ -f ${IOR_LOCKFILE} ]
		do
			errecho ${FUNCNAME} ${LINENO} \
				"Sleeping on llock acquisition for lock owned by"
			errecho ${FUNCNAME} ${LINENO} \
				"$(ls -l ${IOR_LOCKFILE})"
			((++lockcount))
			if [ ${lockcount} -gt ${maxspins} ]
			then
				errecho ${FUNCNAME} ${LINENO} \
					"Exceeded ${maxspins} spins waiting for lock, quitting"
				exit 1
			fi
			sleep 1
		done
		touch ${IOR_LOCKFILE}
	}
	export -f func_getlock
	func_releaselock()
	{
		rm -f ${IOR_LOCKFILE}
	}
	export -f func_releaselock

	mkdir -p ${IOR_TESTDIR} ${IOR_ETCDIR}
	echo $(func_getlock)
	if [ ! -r ${IOR_TESTNUMBERFILE} ]
	then
		echo "0" > ${IOR_TESTNUMBERFILE}
	fi
	if [ ! -r ${IOR_BATCHNUMBERFILE} ]
	then
		echo "0" > ${IOR_BATCHNUMBERFILE}
	fi
	if [ ! -r  ${MD_TESTNUMBERFILE} ]
	then
		echo "0" > ${MD_TESTNUMBERFILE}
	fi
	echo $(func_releaselock)
fi
