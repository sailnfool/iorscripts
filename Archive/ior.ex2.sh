#!/bin/bash
source func.errecho
USAGE="${0##*/} [-vh] [-d #] [-c <tab file>] <ior files> ...\r\n
\t\tprocess a set of ior output files to turn them into suitable\r\n
\t\tcomma separated values (.csv) which are actually <tab> separated.\r\n
\t-v\tverbose output. If specified before -h, you get more.\r\n
\t-h\tPrint this message.\r\n
\t-d\t#\tturn on diagnostics level #\r\n
\t-c\t<tab file>\tThe name of the file which will hold the\r\n
\t\tgenerated summaries which include a header file to explain\r\n
\t\tthe columns.  The default filename is /tmp/${0##*/}.$$.csv,\r\n
\t\ti.e. the \$\$process id is part of the file name.\r\n"
VERBOSE_USAGE="${0##*/} will be used in conjunction with iorunner, a\r\n
\t\tscript that will run a series of tests against a file system with\r\n
\t\ta varying number of processes on systems.  This will produce the\r\n
\t\tior files used as input. See \"iorunner -h\" for\r\n
\t\tmore information.\r\n\r\n
\t\tThese files are suitable for loading into your favorite\r\n
\t\tspreadsheet program to create graphs.  Each line of output\r\r
\t\tis a summary of an ior output file.  Multiple scripts are\r\n
\t\tanticipated.  This script extracts the Max Write, Max Read,\r\n
\t\tcomputes Test Duration from, Start Time, End Time,\r\n
\t\tWrite Units, Read Units, File System, and the Command \r\n
\t\tline that invoked the test.\r\n"

optionargs="vhd:c:"
verbose="FALSE"
debug=0
csvfiledefault="/tmp/${0##*/}.$$.csv"
csvfile=""

while getopts ${optionargs} name
do
	case ${name} in
		h)
			echo -en ${USAGE}
			if [ "${verbose}" = "TRUE" ]
			then
				errecho -e ${LINENO} ${VERBOSE_USAGE}
				echo -en ${VERBOSE_USAGE}
			fi
			exit 0
			;;
		d)
			FUNC_DEBUG=${OPTARG} # see func.errecho
			debug=${OPTARG}
			set -x
			;;
		v)
			verbose="TRUE"
			;;
		c)
			csvfile=${OPTARG}
			;;
		\?)
			errecho "-e" ${LINENO} "invalid option: -${OPTARG}"
			echo ${0##*/} "invalid option"
			;;
	esac
done
if [ -z "${csvfile}" ]
then
	csvfile="${csvfiledefault}"
fi

echo -en "Test Name\tMax Write\tMax Read\tTest Duration\tStart Time\tEnd Time\tWrite Units\tRead Units\tFile System\tCommand Line\r\n" | tee ${csvfile}
for test in $*
do
  testname="${test}"
  date_began=$(sed -n -e '/^Began/s/.*:[  ]//p' ${test})
  date_finished=$(sed -n -e '/^Finished/s/.*:[  ]//p' ${test})
  time_delta=$(date -d @$(( $(date -d "${date_finished}" +%s) - $(date -d "${date_began}" +%s) )) -u +'%H:%M:%S')
  full_maxwrite=$(sed -n -e '/^Max Write:/s/.*:[   ]*\(.*\)$/\1/p' ${test})
  num_maxwrite=$(echo $full_maxwrite | awk '{print $1}')
  units_maxwrite=$(echo $full_maxwrite | awk '{print $2}')
#  num_maxread=$(sed -n -e '/^Max Read:/s/.*:[   ]*\([0-9.]*\)[  ]*.*/\1/p' ${test})
  full_maxread=$(sed -n -e '/^Max Read:/s/.*:[   ]*\(.*\)$/\1/p' ${test})
  num_maxread=$(echo $full_maxread | awk '{print $1}')
  units_maxread=$(echo $full_maxread | awk '{print $2}')
  full_filesystem=$(sed -n -e '/^Path[  ]*:/s/.*:[   ]*\(.*\)$/\1/p' ${test})
  full_commandline=$(sed -n -e '/^Command line[  ]*:/s/.*:[   ]*\(.*\)$/\1/p' ${test})
  #echo -en "${test}\t${num_maxwrite}\t${alt_num_maxwrite}\t${num_maxread}\t${time_delta}\t${date_began}\t${date_finished}\t${alt_date_began}\r\n"
  echo -en "${test}\t${num_maxwrite}\t${num_maxread}\t" | tee -a ${csvfile}
	echo -en "${time_delta}\t${date_began}\t${date_finished}\t" | tee -a ${csvfile}
	echo -en "${alt_date_began}\t${units_maxwrite}\t" | tee -a ${csvfile}
	echo -en "${units_maxread}\t${full_filesystem}\t" | tee -a ${csvfile}
	echo -en "${full_commandline}\r\n" | tee -a ${csvfile}
done
