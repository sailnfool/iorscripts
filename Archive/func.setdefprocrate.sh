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
# setdefprocrate $exec ${iorbatchstring} ${iortestnumber} $fspath $numprocs $guesstime/0 GUESS/OBSERVED
################################################################################
if [ -z "${__funcsetdefprocrate}" ]
then
	export __funcsetdefprocrate=1
	source func.errecho
	source func.insufficient
	source func.arithmetic
	source func.logger

	function setdefprocrate()
	{
		if [ -z "${IOR_TESTDIR}" ]
		then
			errecho ${FUNCNAME} ${LINENO} "Environment variable IOR_TESTDIR not set"
			exit 1
		else
			IOR_ETCDIR=${IOR_TESTDIR}/etc
		fi
		NUMARGS=8
		if [ $# -lt ${NUMARGS} ]
		then
			insufficient ${LINENO} ${FUNCNAME} ${NUMARGS} $@
		fi
		execname="$1"  #the name of the executable (may not be basename)
		processid="$2"
		batchstring="$3"
		testnumber="$4"
		fspath="$5"    #the file system under test
		numprocs="$6"  #the number of processes used to determine a default
		guesstime="$7" #the guessed time to run numprocs in seconds
		gobs="$8"      #are we making a guess or an observed value

		if [ -z "${execname}" ]
		then
			nullparm ${FUNCNAME} ${LINENO} 1 "execname"
		fi
		if [ -z "${fspath}" ]
		then
			nullparm ${FUNCNAME} ${LINENO} 2 "fspath"
		fi
		if [ -z "${numprocs}" ]
		then
			nullparm ${FUNCNAME} ${LINENO} 3 "numprocs"
		fi
		if [ -z "${guesstime}" ]
		then
			nullparm ${FUNCNAME} ${LINENO} 4 "guesstime"
		fi
		if [ -z "${gobs}" ]
		then
			nullparm ${FUNCNAME} ${LINENO} 5 "gobs"
		fi

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
		fileprefix=${upper_exec}.${fsbase}

		default_procrate_filename=${fileprefix}.procrate.txt
		procrate_file=${IOR_ETCDIR}/${default_procrate_filename}

		default_procrate_minfilename=${fileprefix}.default.txt
		procrate_minfile=${IOR_ETCDIR}/${procrate_default_minfilename}

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
		# If we are making a guess and the guesstime is ZERO, then we will
		# check to see if there is a procrate default.  If there is we will
		# use that.  If there is not, then we will use 60 seconds
		####################
		case ${gobs} in
			GUESS)
				if [ ${guesstime} -eq 0 ]
				then
					if [ -r ${procrate_file} ]
					then
						guesstime=$(cat ${procrate_file})
					else
						guesstime=60
					fi
				fi
				;;
			OBSERVED)
				if [ ${guesstime} -eq 0 ]
				then

					####################
					# There is a potential problem here.  The observed times are
					# based on a date stamp.  If the process ran quickly enough
					# we could have gotten a ZERO time.  Unlikely, but possible
					####################
					errecho ${FUNCNAME} ${LINENO} "Observed time of ZERO illegal"
					exit 1
				fi
				;;
			\?)
				errecho ${FUNCNAME} ${LINENO} "Invalid gobs value=${gobs}"
				exit 1
				;;
		esac

		errecho ${FUNCNAME} ${LINENO} "PROC_BAND=${PROC_BAND}" >&2

		((one_ms_second=1000))
		((milliseconds=guesstime*one_ms_second))
		((perprocms=milliseconds/numprocs))
		((perprocms+=(((milliseconds%numprocs>0)?1:0))))
		band=$(func_introundup ${numprocs} ${PROC_BAND})
		errecho ${FUNCNAME} ${LINENO} "band=${band}" >&2

		####################
		# Now we find out if there is a procrate_file.  If there is not
		# we will create a single line from what we have and quit.
		####################
		if [ ! -r ${procrate_file} ]
		then
			echo "${band}|${perprocms}|${perprocms}|${gobs}" >> ${procrate_file}
#			errecho ${FUNCNAME} ${LINENO} "procrate_file=${procrate_file}" >&2
			echo ${perprocms}
			exit 0
		fi

		tmpfile=/tmp/${USER}.$$.${default_procrate_filename}
	
		case ${gobs} in
			GUESS)

				###################
				# if we are making a guess, see if there is already a guess in the
				# procrate_file.  We can't get here unless the prior guess was not
				# found.
				###################
				if [ $(egrep "^${band}|.*|GUESS$" ${procrate_file} | wc -l) -ge 1 ]
				then
#					errecho ${FUNCNAME} ${LINENO} "You are making a second guess for band=${band}" >&2
					cat ${procrate_file} > ${tmpfile}
				else
					echo "${band}|${perprocms}|${perprocms}|${gobs}" > ${tmpfile}
				fi
				;;
			OBSERVED)

				###################
				# if there is more than one line int the procrate file for the same
				# band of number of proces, e.g.:
				# 100|750|750|GUESS
				# 100|1000|1000|OBSERVED
				#
				# Then the following deletes the GUESS lines
				###################
				while [ $(fgrep "^${band}|" ${procrate_file} | wc -l) -ge 1 ]
				do

					$(fgrep -v "^${band}|.*|GUESS$" ${procrate_file} ) > ${tmpfile}

					mv ${tmpfile} ${procrate_file}
					# cat ${procrate_file}
				done

				###################
				# Now get the non-GUESS (aka OBSERVED) line and see if the perprocms
				# that we got up earlier is above or below the current high/low values
				# Don't let a low value drop to zero.
				###################
				line=$(fgrep "^${band}|" ${procrate_file})
				low_perprocms=$(echo $line | awk -F "|" '{print $2}')
				high_perprocms=$(echo $line | awk -F "|" '{print $3}')
				((low_perprocms=(((perprocms<low_perprocms)?perprocms:low_perprocms))))
				((high_perprocms=(((perprocms>high_perprocms)?perprocms:high_perprocms))))
				((low_perprocms=(((low_perprocms==0)?high_perprocms:low_perprocms))))

				echo $(fgrep -v "^${band}|" ${procrate_file} ) > ${tmpfile} >&2
				
				$(fgrep -v "^${band}|" ${procrate_file} ) > ${tmpfile} >&2

				echo "${band}|${low_perprocms}|${high_perprocms}|OBSERVED" >> ${tmpfile}
				;;
		esac

		####################
		# sort the procrate_file in numeric order of the first field (base).
		####################
		sort -u -n -t "|" ${tmpfile} > ${procrate_file}
		errecho ${FUNCNAME} ${LINENO} "procrate_file=${procrate_file}" >&2

		####################
		# Log that we updated procrate
		####################
		$(logger "RATE" "${execname}" "$$" "${batchstring}" "${testnumber}" "${base}" "${guesstime}" "${numprocs}" "${band}" "${perprocms}")
		errecho ${FUNCNAME} ${LINENO} "procrate_file=${procrate_file}" >&2
		echo ${perprocms}
		exit 0
 	}
 	export -f setdefprocrate
fi # if [ -z "${__funcsetdefprocrate}" ]
# vim: set syntax=bash, ts=2, sw=2, lines=55, columns=120,colorcolumn=78
