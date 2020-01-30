#!/bin/bash
#######################################################################
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
#######################################################################
if [ -z "${__funcgetprocrate}" ]
then
	export __funcgetprocrate=1
	source func.global
	source func.errecho
	source func.insufficient
	source func.arithmetic
	source func.setdefprocrate
#
	function get_procrate()
	{
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
		upper_exec=$(echo ${execbase}|tr [:lower:] [:upper:])
		fsbasename=${filesystem##*/}
		numprocs=${ratenumprocs}

    ####################
		# The data table is "banded" by all testing done in the same 
		# centurion (group of one hundred).  We round up the number of
		# reported processes to the next multiple of 100.  This is
		# arbitrary and finer grained groups are possible, simply by
		# redefining the value of "procband.txt"
    ####################

    ####################
		# the leading part of the process rate table is an upper case
		# representation of the test's base name
		#
		# Assume we only got uppercase values.
    ####################
		fileprefix=${execname}.${fsbase}

		procrate_file=${IOR_ETCDIR}/${fileprefix}.${PROCRATE_SUFFIX}
		procrate_minfile=${IOR_ETCDIR}/${fileprefix}.${PROCRATEMIN_SUFFIX}
		procband_file=${IOR_ETCDIR}/${fileprefix}.${PROCBAND_SUFFIX}

		if [ -z "${PROC_BAND}" ]
		then
			if [ ! -r ${procband_file} ]
			then
				echo "100" > ${procband_file}
			fi
			export PROC_BAND=$(cat ${procband_file})
		fi

		if [ -r ${procrate_minfile} ]
		then
			guess=$(cat ${procrate_minfile} )
		else
			guess=1
			echo ${guess} > ${procrate_minfile}
		fi

    ####################
		# if there is no procrate file, 
		# tell setdefprocratefile to guess and put that in procratefile
    ####################
	  if [ ! -e ${procrate_file} ]
		then
			echo $(setdefprocrate ${upper_exec} "$$" "getproc" "999999999" \
${fsbasename} ${numprocs} ${guess} "GUESS" )
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

		if [ "$(cat ${procrate_file}|wc -l)" -eq 0 ]
		then
			errecho ${FUNCNAME} ${LINENO} "No lines in ${procrate_file}"
			exit 1
		fi
    ####################
		# since we have a procrate file return the number milliseconds
		# per process for this band in the table
    ####################
		centurion=$(func_introundup ${ratenumprocs} ${PROC_BAND})
		#errecho ${FUNCNAME} ${LINENO} "centurion=${centurion}" >&2

    ####################
		# The file has been sorted in ascending numeric order by the
		# first field.
		#
		# We have to read squentially through the file to get the largest
		# value less than or equal to centurion
    ####################
		while IFS= read -r line; do
			#errecho ${FUNCNAME} ${LINENO} "line=$line" >&2
			centurionband=$(echo $line | awk -F "|" '{print $1}')
			#errecho ${FUNCNAME} ${LINENO} "centurionband=$centurionband" >&2
			low_milliseconds=$(echo $line | awk -F "|" '{print $2}')
			#errecho ${FUNCNAME} ${LINENO} "low_milliseconds=$low_milliseconds" >&2
			high_milliseconds=$(echo $line | awk -F "|" '{print $3}')
			#errecho ${FUNCNAME} ${LINENO} "high_milliseconds=$high_milliseconds" >&2

			if [ -z "${low_milliseconds}" ]
			then
				low_milliseconds=${one_ms_second}
			fi
			if [ -z "${high_milliseconds}" ]
			then
				high_milliseconds=${one_ms_second}
			fi
			#errecho ${FUNCNAME} ${LINENO} \
				#"line=${line}" >&2
			#errecho ${FUNCNAME} ${LINENO} \
				#"centurionband=${centurionband}" >&2
			#errecho ${FUNCNAME} ${LINENO} \
				#"low_milliseconds=${low_milliseconds}" >&2
			#errecho ${FUNCNAME} ${LINENO} \
				#"high_milliseconds=${high_milliseconds}" >&2
			if [ "${centurionband}" -ge "${centurion}" ]
			then
				break
			fi
		done < ${procrate_file}
		# If no match was found, we use the last entry as the proxy
		# for a new higher set.
		if [ -z "${high_milliseconds}" ]
		then
			errecho ${FUNCNAME} ${LINENO} \
				"high_milliseconds is NULL" >&2
			errecho ${FUNCNAME} ${LINENO} \
				"line=${line}" >&2
			errecho ${FUNCNAME} ${LINENO} \
				"centurionband=${centurionband}" >&2
			errecho ${FUNCNAME} ${LINENO} \
				"low_milliseconds=${low_milliseconds}" >&2
			errecho ${FUNCNAME} ${LINENO} \
				"high_milliseconds=${high_milliseconds}" >&2
			exit 1
		fi

		####################
		# Verify that high_milliseconds is an integer
		####################
		reinteger='^[0-9]+$'
		# resignedinteger='^[+-]?[0-9]+$'
		# resigneddecimal='^[+-]?[0-9]+([.][0-9]+)?$'
		if [[ ! "${high_milliseconds}" =~ ${reinteger} ]]
		then
			errecho ${FUNCNAME} ${LINENO} \
        "high_milliseconds not an integer"
			errecho ${FUNCNAME} ${LINENO} \
				"line=${line}" >&2
			errecho ${FUNCNAME} ${LINENO} \
				"centurionband=${centurionband}" >&2
			errecho ${FUNCNAME} ${LINENO} \
				"low_milliseconds=${low_milliseconds}" >&2
			errecho ${FUNCNAME} ${LINENO} \
				"high_milliseconds=${high_milliseconds}" >&2
			exit 1
		else
			if [ ${high_milliseconds} -eq 0 ]
			then
				errecho ${FUNCNAME} ${LINENO} \
          "high_milliseconds must be non-zero"
			errecho ${FUNCNAME} ${LINENO} \
				"line=${line}" >&2
			errecho ${FUNCNAME} ${LINENO} \
				"centurionband=${centurionband}" >&2
			errecho ${FUNCNAME} ${LINENO} \
				"low_milliseconds=${low_milliseconds}" >&2
			errecho ${FUNCNAME} ${LINENO} \
				"high_milliseconds=${high_milliseconds}" >&2
				exit 1
			fi
		fi
		echo ${high_milliseconds}
	}
	export -f get_procrate
fi # if [ -z "${__funcgetprocrate}" ]
# vim: set syntax=bash, ts=2, sw=2, lines=55, columns=120,colorcolumn=78
