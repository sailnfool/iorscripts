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
# 400|510|150|OBSERVED
#
# Initialization comes from EXEC.fsbase.defaults.txt
#
# BANDSIZE|DEFMS|FAILPERCENT
# 100|600|20
#
# The defaults shown above reflects bands of 100 processes, 
# 100 process in one minute (60 seconds / 100 processes ) * 1000 ms/sec
# 20 percent increase.  If an srun fails, increase the next srun by
# 20 percent.
#
#######################################################################
if [ -z "${__funcinitprocrate}" ]
then
	export __funcinitprocrate=1
	source func.global2
	source func.errecho
	source func.insufficient
#
	function init_globals()
	{
    ####################
		# get_procrate $upperbase $fsbase $numprocs
    ####################
		NUMARGS=2
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

		execbase=${execname##*/}
		upper_exec=$(echo ${execbase}|tr [:lower:] [:upper:])
		fsbase=${filesystem##*/}
		numprocs=${ratenumprocs}

    ####################
		# The data table is "banded" by all testing done in the same 
		# centurion (group of one hundred).  We round up the number of
		# reported processes to the next multiple of 100.  This is
		# arbitrary and finer grained groups are possible, simply by
		# redefining the default value
		####################
set -x
    ####################
		# the leading part of the process rate table is an upper case
		# representation of the test's base name
		#
		# Assume we only got uppercase values.
    ####################
		fileprefix=${upper_exec}.${fsbase}

		procdefault_file=${IOR_ETCDIR}/${fileprefix}.${PROCDEFAULT_SUFFIX}

		if [ ! -r ${procdefault_file} ]
		then
			errecho ${FUNCNAME} ${LINENO} "File Not Found ${procdefault_file}"
			errecho ${FUNCNAME} ${LINENO} \
				"Need Default Band (e.g. 100), default MS per Process and..."
			errecho ${FUNCNAME} ${LINENO} \
				"the amount by which to increase guess times after failures"
			exit 1
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
			errecho ${FUNCNAME} ${LINENUM} \
				"Could not read ${procdefault_file}"
			exit 1
		fi
		exit 0
	}
	export -f init_globals
	function init_procrate()
	{
    ####################
		# get_procrate $upperbase $fsbase $numprocs
    ####################
		NUMARGS=2
		if [ $# -lt ${NUMARGS} ]
		then
			insufficient ${LINENO} ${FUNCNAME} ${NUMARGS} $@
		fi
		execname="$1"       #the basename of the executable
		filesystem="$2"  #the filesystem under test

		if [ -z "${execname}" ]
		then
			nullparm ${LINENO} ${FUNCNAME} 1
		fi
		if [ -z "${filesystem}" ]
		then
			nullparm ${LINENO} ${FUNCNAME} 2
		fi

		execbase=${execname##*/}
		upper_exec=$(echo ${execbase}|tr [:lower:] [:upper:])
		fsbase=${filesystem##*/}
		numprocs=${ratenumprocs}

    ####################
		# The data table is "banded" by all testing done in the same 
		# centurion (group of one hundred).  We round up the number of
		# reported processes to the next multiple of 100.  This is
		# arbitrary and finer grained groups are possible, simply by
		# redefining the default value
		####################

    ####################
		# the leading part of the process rate table is an upper case
		# representation of the test's base name
		#
		# Assume we only got uppercase values.
    ####################
		fileprefix=${upper_exec}.${fsbase}

		procrate_file=${IOR_ETCDIR}/${fileprefix}.${PROCRATE_SUFFIX}

		if [ ! -r ${procrate_file} ]
		then
			errecho ${FUNCNAME} ${LINENO} \
				"File Not Found ${procdefault_file}"
			errecho ${FUNCNAME} ${LINENO} \
				"Creating a one-line default table"
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
			echo ${!lo_ms[@]}
		done < ${procrate_file}
		IFS=$OLDIFS
		
		if [ ${linesread} -eq 0 ]
		then
			errecho ${FUNCNAME} ${LINENO} 
				"Could not read ${procrate_file}"
			exit 1
		fi
		exit 0
	}
	export -f init_procrate
	function dump_procrate()
	{
		set -x
    ####################
		# get_procrate $upperbase $fsbase $numprocs
    ####################
		NUMARGS=2
		if [ $# -lt ${NUMARGS} ]
		then
			insufficient ${LINENO} ${FUNCNAME} ${NUMARGS} $@
		fi
		execname="$1"       #the basename of the executable
		filesystem="$2"  #the filesystem under test

		if [ -z "${execname}" ]
		then
			nullparm ${LINENO} ${FUNCNAME} 1
		fi
		if [ -z "${filesystem}" ]
		then
			nullparm ${LINENO} ${FUNCNAME} 2
		fi

		execbase=${execname##*/}
		upper_exec=$(echo ${execbase}|tr [:lower:] [:upper:])
		fsbase=${filesystem##*/}
		numprocs=${ratenumprocs}

    ####################
		# The data table is "banded" by all testing done in the same 
		# centurion (group of one hundred).  We round up the number of
		# reported processes to the next multiple of 100.  This is
		# arbitrary and finer grained groups are possible, simply by
		# redefining the default value
		####################

    ####################
		# the leading part of the process rate table is an upper case
		# representation of the test's base name
		#
		# Assume we only got uppercase values.
    ####################
		fileprefix=${upper_exec}.${fsbase}

		procrate_file=${IOR_ETCDIR}/${fileprefix}.${PROCRATE_SUFFIX}

		if [ -r ${procrate_file} ]
		then
			mv ${procrate_file} ${procrate_file}.$$.save
		fi

		for band in "${!lo_ms[@]}"
		do
			echo "${band}|${lo_ms[${band}]}|${hi_ms[${band}]}|${gobs[${band}]}" \
				>> ${procrate_file}
		done
		exit 0
	}
	export -f dump_procrate
fi # if [ -z "${__funcinitprocrate}" ]
# vim: set syntax=bash, ts=2, sw=2, lines=55, columns=120,colorcolumn=78
