#!/bin/bash
################################################################################
#
# Given an executable, filesystem, and number of
# processes, set up a default process rate and table.
#
# Incoming Environment variables:
# IOR_TESTDIR The directory where test results are stored.  This directory
#             is a peer of src, doc, etc.  defaults to testdir.  This is 
#             distinct from testing (another peer) which may contain a
#             source tree for tests that are run, including the src and scripts
#             that are used for testing.
# PROC_BAND   Since we are testing in an MP environment, this is used to store
#             observed or guessed execution time per process in this bank for
#             each process when N processes are run.  E.G. a PROC_BAND value
#             of 100 means that we will assume that for processes in the range
#             1-100, the total execution time won't exceed the high_procrate
#             stored for this band in the procrate table.
#
# execname="$1"
# fspath="$2"
# numprocs="$3"
################################################################################
#
# The following are derived from the above:
#
# execbase (basename of the executable)
# fsbase   (basename of the filesystem under test)
#
# IOR_ETCDIR The etc directory which contains data about running the test
#            or benchmark and may define default initial values if there
#            are no derived values present.
#
# XXX.YYY.procrate.txt	The table of process rates.  Times in the table are
#            stored in milliseconds per process.  We track low/high.  Guessed
#            rates should have the same low and high
#
#		BAND|Low ms|High ms|Guess/Observed
#
# ~/bin       The directory where testing executables are placed since
#             we assume that ~/bin is part of the tester's $PATH this
#             may only be relevant to the makefile
#
# setdefprocrate $exec $fspath $numprocs $guesstime/0 GUESS/OBSERVED
################################################################################
	source func.global
	source func.errecho
	source func.insufficient
	source func.arithmetic
	source func.logger
	source func.setdefprocrate

		execname="ior"  #the name of the executable (may not be basename)
		fspath="/p/lustre3"    #the file system under test
		numprocs="4"  #the number of processes used to determine a default
		guesstime="60" #the guessed time to run numprocs in seconds
		gobs="GUESS"      #are we making a guess or an observed value

		fsbase=${fspath##*/}

		####################
		# Verify that numprocs and guesstime are both integer values
		####################
		reinteger='^[0-9]+$'
		# resignedinteger='^[+-]?[0-9]+$'
		# resigneddecimal='^[+-]?[0-9]+([.][0-9]+)?$'
		if [[ ! "${numprocs}" =~ ${reinteger} ]]
		then
			errecho ${FUNCNAME} ${LINENO} "Parameter #3 numprocs not an integer=$3"
			exit 1
		else
			if [ ${numprocs} -eq 0 ]
			then
				errecho ${FUNCNAME} ${LINENO} "Parameter #3 numprocs must be non-zero, numprocs=$3"
				exit 1
			fi
		fi
		if [[ ! "${guesstime}" =~ ${reinteger} ]]
		then
			errecho ${FUNCNAME} ${LINENO} "Parameter #4 guesstime not an integer=$4"
			exit 1
		fi

		####################
		# the leading part of the process rate table name is an upper case
		# representation of the test's (benchmark's) base name.  These files
		# are found in the IOR_ETCDIR
		####################
		upper_exec=$(echo ${execname##*/}|tr [:lower:] [:upper:])
		default_procrate_filename=${upper_exec}.${fsbase}.procrate.txt
		procrate_file=${IOR_ETCDIR}/${default_procrate_filename}
		procrate_default_filename=${upper_exec}.${fsbase}.default.txt
		procrate_default_file=${IOR_ETCDIR}/${procrate_default_filename}

		echo $(setdefprocrate ${upper_exec} $$ "dummy" 999999 ${fsbase} \
			${numprocs} 0 "GUESS" 150)
		echo $(setdefprocrate ${upper_exec} $$ "dummy" 999999 ${fsbase} \
			${numprocs} 6 "OBSERVED" 150)
		more ${IOR_ETCDIR}/*.txt
