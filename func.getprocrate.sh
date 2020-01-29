#!/bin/bash
################################################################################
# This script will retrieve from the procrate table the lowest number of 
# processes per hour that can support the current number of processes passed
# as an argument.
#
# The parent process is responsible for turning that into an estimate of
# the amount of scheduled time.  I.E.:
#
# number of seconds = ( Returned_Rate * 100000 ) / number_of_procs
#
# This retrieves the Worst rate (although it stores best and worst) for
# a number of processes in this centurion (band of 100 processes).
#
# Numprocs Band|Worst Processes/hour|Best processes/Hour
# 100|150|600|GUESS
# 200|450|740|GUESS
# 400|510|150
#
#
if [ -z "${__funcgetprocrate}" ]
then
	export __funcgetprocrate=1
	source func.errecho
	source func.insufficient
	source func.arithmetic
	source func.setdefprocrate
#
	function get_procrate()
	{
		if [ -z "${IOR_TESTDIR}" ]
		then
			errecho ${FUNCNAME} ${LINENO} "Environment variable IOR_TESTDIR not set"
			exit 1
		fi
		IOR_ETCDIR=${IOR_TESTDIR}/etc
		
    ####################
		# get_procrate $execbase $fsbasename $numprocs
    ####################
		NUMARGS=3
		if [ $# -lt ${NUMARGS} ]
		then
			insufficient ${LINENO} ${FUNCNAME} ${NUMARGS} $@
		fi
		execname="$1"       #the basename of the executable
		filesystem="$2"  #the filesystem under test
		ratenumprocs="$3"    #the number of processes we want to test

		if [ -z "${execname}" ]
		then
			nullparm ${LINENO} ${FUNCNAME} 1
		fi
		if [ -z "${filesystem}" ]
		then
			nullparm ${LINENO} ${FUNCNAME} 2
		fi
		if [ -z "${ratenumprocs}" ]
		then
			nullparm ${LINENO} ${FUNCNAME} 3
		fi

		execbase=${execname##*/}
		fsbasename=${filesystem##*/}
		numprocs=${ratenumprocs}

    ####################
		# The data table is "banded" by all testing done in the same centurion
		# (group of one hundred).  We round up the number of reported processes
		# to the next multiple of 100.  This is arbitrary and finer grained
		# groups are possible, simply by redefining the value of "procband.txt"
    ####################

    ####################
		# the leading part of the process rate table is an upper case
		# representation of the test's base name
    ####################
		upper_exec=$(echo ${execbase}|tr [:lower:] [:upper:])
		fileprefix=${upper_exec}.${fsbasename}

		default_procrate_filename=${fileprefix}.procrate.txt
		procrate_file=${IOR_ETCDIR}/${default_procrate_filename}

		default_procrate_minfilename=${fileprefix}.default.txt
		procrate_minfile=${IOR_ETC_DIR}/${default_procrate_minfilename}

		default_procband_filename=${fileprefix}.procband.txt
		procband_file=${IOR_ETCDIR}/${default_procband_filename}
		if [ -z "${PROC_BAND}" ]
		then
			if [ ! -r ${procband_file} ]
			then
				echo "100" > ${procband_file}
			fi
			export PROC_BAND=$(cat ${procband_file})
		fi

    ####################
		# if there is no procrate file, 
		# tell setdefprocratefile to guess and put that in procratefile
    ####################
	  if [ ! -e ${procrate_file} ]
		then
			echo $(setdefprocrate ${execbase} "$$" "getproc" "999999999" ${fsbasename} ${numprocs} 0 "GUESS" ) >/dev/null
		fi

    ####################
		# This should never happen!!!!
    ####################
	  if [ ! -e ${procrate_file} ]
		then
			errecho ${FUNCNAME} ${LINENO} "procrate_file=${procrate_file}"
			errecho ${FUNCNAME} ${LINENO} "file not found!!!!"
			exit 1
		fi

    ####################
		# since we have a procrate file return the number of procs per
		# hour for this band
    ####################
		centurion=$(func_introundup ${ratenumprocs} ${PROC_BAND})
		errecho ${FUNCNAME} ${LINENO} "centurion=${centurion}" >&2

    ####################
		# We have to read squentially through the file to get the largest
		# value less than or equal to centurion
    ####################
		while IFS= read -r line; do
			centurionband=$(echo $line | awk -F "|" '{print $1}')
			low_milliseconds=$(echo $line | awk -F "|" '{print $2}')
			high_milliseconds=$(echo $line | awk -F "|" '{print $3}')
			errecho ${FUNCNAME} ${LINENO} "line=${line}" >&2
			errecho ${FUNCNAME} ${LINENO} "centurionband=${centurionband}" >&2
			errecho ${FUNCNAME} ${LINENO} "low_milliseconds=${low_milliseconds}" >&2
			errecho ${FUNCNAME} ${LINENO} "high_milliseconds=${high_milliseconds}" >&2
			if [ "${centurionband}" -ge "${centurion}" ]
			then
				break
			fi
		done < ${procrate_file}
		# If no match was found, we use the last entry as the proxy for a new
		# higher set.
		echo ${high_milliseconds}
	}
	export -f get_procrate
fi # if [ -z "${__funcgetprocrate}" ]
# vim: set syntax=bash, ts=2, sw=2, lines=55, columns=120,colorcolumn=78
