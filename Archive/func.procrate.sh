#!/bin/bash
################################################################################
#
# Given an executable, filesystem, deltatime (in seconds) and number of
# processes, compute the number of processes per second that were processed.
# store that information in a file which remembers the WORST rate for this
# combination of a test and a number of processes.
#
# Numprocs|Worst Processes/hour|Best Processes/Hour
#	100|60|600
# 200|30|300
# 400|15|150
#
# from these two values, in a table, we seek through the table to find the
# first of the entries that is larger than the requested processes
# and divide the requested number of processes by processes per second to
# determine the number of seconds to request.  That is done by a 
# a complementary script, getprocrate included below.
#
# Unfortunately due to the scheduling by SLURM/Srun, the time for the test
# will include the test "waiting for resources" time.  We don't get a time
# stamp from srun that notifies us of the start time, so we can only extract
# this from the output files of the test program assuming that it outputs
# start and stop times.  An enhancement would be to look for the output of
# the test and have the "extractor" programs that convert the benchmark
# output into CSV files, make another call to this process to provide more
# refined data.  If we do this, then we may want to add a fourth column to
# the data table, that differentiates between elapsed time vs. the actual
# run time in the benchmark program.
#
################################################################################
if [ -z "${__funcprocrate}" ]
then
	export __funcprocrate=1
	source func.errecho
	source func.insufficient
	source func.arithmetic
	source func.logger

	function procrate()
	{
		if [ -z "${IOR_TESTDIR}" ]
		then
			errecho ${LINENO} ${FUNCNAME} "Environment variable IOR_TESTDIR not set"
			exit 1
		else
			IOR_ETCDIR=${IOR_TESTDIR}/etc
		fi
		NUMARGS=4
		if [ $# -lt ${NUMARGS} ]
		then
			insufficient ${LINENO} ${FUNCNAME} ${NUMARGS} $@
		fi
		rate_exec="$1"       #the basename of the executable
		rate_processid="$2"  #the process id of the parent process
		rate_batch="$3"      #the batchnumber for a group of tests
		rate_test="$4"       #the testnumber in a group of tests (usually a global)
		ratefilesystem="$5"  #the file system under test
		ratedelta="$6"       #the time in seconds for the test
		ratenumprocs="$7"    #the number of processes that were tested

		if [ -z "${rate_exec}" ]
		then
			nullparm ${LINENO} ${FUNCNAME} 1
		fi
		if [ -z "${rate_processid}" ]
		then
			nullparm ${LINENO} ${FUNCNAME} 2
		fi

		####################
		# Note that rate_batch is missing from this list.  If you are running
		# a standalone process that is not part of a batch this can be
		# legitimately null  The parameter is here and documented for uniformity
		# in all logging based functions.
		####################
		if [ -z "${rate_test}" ]
		then
			nullparm ${LINENO} ${FUNCNAME} 4
		fi
		if [ -z "${ratefilesystem}" ]
		then
			nullparm ${LINENO} ${FUNCNAME} 5
		fi
		if [ -z "${ratedelta}" ]
		then
			nullparm ${LINENO} ${FUNCNAME} 6
		fi
		if [ -z "${ratenumprocs}" ]
		then
			nullparm ${LINENO} ${FUNCNAME} 7
		fi

		####################
		# The data table is "banded" by all testing done in the same
		# centurion (group of one hundred).  We round up the number of
		# reported processes to the next multiple of 100.  This is arbitrary
		# and finer grained groups are possible, simply by redefining the
		# value of "band"
		####################
		band=100

		####################
		# the leading part of the process rate table is an upper case
		# representation of the test's base name
		####################
		upper_exec=$(echo ${rate_exec##*/}|tr [:lower:] [:upper:])
		default_procrate_filename=${upper_exec}.${ratefilesystem##*/}.procrate.txt

		####################
		# Check to see if the procrate table was set as an environmnent
		# variable in a calling process.  If it was, then use that else
		# use the default directory and the default name.
		####################
		if [ -z "${IOR_PROCRATE}" ]
		then
			procratefile=${IOR_ETCDIR}/${default_procrate_filename}
		else
			procratefile=${IOR_PROCRATE}
		fi
		if [ ! -r ${procratefile} ]
		then
			touch ${procratefile}
		fi
		
		####################
		# Defensive to avoid division by zero
		####################
		if [ ${ratedelta} -eq 0 ]
		then
			errecho ${FUNCNAME} ${LINENO} "rate delta is ZERO? ratedelta=${ratedelta}"
			exit 1
		fi

		#
		# Defensive to avoid divide by zero
		#
		if [ ${ratenumprocs} -eq 0 ]
		then
			errecho ${FUNCNAME} ${LINENO} "rate numprocs is ZERO? ratenumprocs=${ratenumprocs}"
			exit 1
		fi
		# decimicroseconds  (rate *100000) = ( time * 100000 ) / numprocs
		((decimicroseconds=ratedelta*100000))
		((thisrate=decimicroseconds/ratenumprocs))
		centurion=$(func_introundup ${ratenumprocs} ${band})
		((centurionrate=centurion*thisrate))

		####################
		# See if the centurion (to a multiple of 100) number of processes is
		# in the table.  If it is not, then append this rate to the end of
		# the rate table.  If the table does not exist, this will create
		# it with one line.
		####################
		egrep "^${centurion}" ${procratefile} > /dev/null
		if [ "$?" -ne 0 ]
		then
			echo "${centurion}|${centurionrate}|${centurionrate}" >> ${procratefile}
		fi

	  ####################
		# Retrieve the low and high rates previously saved in the table for this
		# band
	  ####################
		low_centurionrate=$(awk -F "|" "/^${centurion}/ {print \$2}" ${procratefile})
		high_centurionrate=$(awk -F "|" "/^${centurion}/ {print \$3}" ${procratefile})

	  ####################
		# If we found a new low, replace the value
	  ####################
		if [ ${centurionrate} -lt ${low_centurionrate} ]
		then
			low_centurionrate=${centurionrate}
		fi
		
	  ####################
		# If we found a new high, replace the value
	  ####################
		if [ ${centurionrate} -gt ${high_centurionrate} ]
		then
			high_centurionrate=${centurionrate}
		fi

		####################
		# Use an identifiable temporary file name.  /tmp is different on each
		# node
		####################
		tmpprocfilename=/tmp/$USER.$$.${default_procrate_filename}

		####################
		# filter out all but the "line of interest" from the table
		####################
		# egrep -v "^${centurion}|" ${procratefile} > ${tmpprocfilename}
		sed "/^${centurion}|/d" ${procratefile} > ${tmpprocfilename}

		####################
		# append the replacement entry to the end of the table
		####################
		echo "${centurion}|${low_centurionrate}|${high_centurionrate}" >> ${tmpprocfilename}

		####################
		# sort the table in ascending numeric order
		####################
		sort -u -n -t "|" ${tmpprocfilename} > ${procratefile}
		rm -f ${tmpprocfilename}

		####################
		# log that we have updated the table
		####################
		now_date=$(date)
		$(logger "RATE" "${rate_exec}" "$$" "${rate_batch}" "${rate_test}" "${ratefilesystem}" "${rate_delta}" "${ratenumprocs}" "${centurion}" "${centurionrate}")
	}
	export -f procrate
fi # if [ -z "${__funcprocrate}" ]
# vim: set syntax=bash, ts=2, sw=2, lines=55, columns=120,colorcolumn=78
