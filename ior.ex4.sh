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
# csvfiledefault="/tmp/${0##*/}.$$.csv"
pwdpath=$(pwd)
csvfiledefault="${pwdpath}/${pwdpath##*/}.csv"
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
rm -f ${csvfile}
touch ${csvfile}
# write out the header labels for the comma separated values file
echo -en "Test Name\t" | tee -a ${csvfile} # test
echo -en "Max Write\t" | tee -a ${csvfile} # num_maxwrite
echo -en "Max Read\t" | tee -a ${csvfile} # num_maxread
echo -en "Test Duration\t" | tee -a ${csvfile} # time_delta
echo -en "Start Time\t" | tee -a ${csvfile} # date_began
echo -en "End Time\t" | tee -a ${csvfile} # date_finished
echo -en "Write Units\t" | tee -a ${csvfile} # units_maxwrite
echo -en "Read Units\t" | tee -a ${csvfile} # units_maxread
echo -en "File System\t" | tee -a ${csvfile} # full_filesystem
echo -en "Command Line\t" | tee -a ${csvfile} # full_commandline
echo -en "Machine ID\t" | tee -a ${csvfile} # machine
echo -en "API\t" | tee -a ${csvfile} # api
echo -en "Type of Access\t" | tee -a ${csvfile} # access
echo -en "Type of I/O\t" | tee -a ${csvfile} # type_of_io
echo -en "Num Segments\t" | tee -a ${csvfile} # segments
echo -en "Ordering in a file\t" | tee -a ${csvfile} # ordering_in_a_file
echo -en "Ordering inter file\t" | tee -a ${csvfile} # ordering_inter_file
echo -en "Task Offset\t" | tee -a ${csvfile} # task_offset
echo -en "Num Nodes\t" | tee -a ${csvfile} # nodes
echo -en "Num Tasks\t" | tee -a ${csvfile} # tasks
echo -en "Clients per Node\t" | tee -a ${csvfile} # clients_per_node
echo -en "Repetitions\t" | tee -a ${csvfile} # repetitions
echo -en "Transfer size\t" | tee -a ${csvfile} # xfersize
echo -en "Block size\t" | tee -a ${csvfile} # blocksize
echo -en "Aggregate File Size\t" | tee -a ${csvfile} # aggregate_filesize
echo -en "TestID\t" | tee -a ${csvfile} # testid
echo -en "filername\t" | tee -a ${csvfile} # short_filesystem
#echo -en "FS\t" | tee -a ${csvfile} # FS
echo -en "Filer Space\t" | tee -a ${csvfile} # filer_space
echo -en "Filer Space used %\t" | tee -a ${csvfile} # filer_space_used_percent
echo -en "Filer inodes\t" | tee -a ${csvfile} # filer_inodes
echo -en "Filer inode used %\t" | tee -a ${csvfile} # filer_inode_used_percent
echo -en "Benchmark\t" | tee -a ${csvfile} # benchmark_name
echo -en "Description\t" | tee -a ${csvfile} # benchmark_description
# echo -en "yyyy\t" | tee -a ${csvfile} # xxxx
echo -en "\r\n" | tee -a ${csvfile}
for test in $*
do
	# We will read the output file many, many times because the data is not
	# in a form that is amenable for loading into a spreadsheet (e.g., csv)
  testname="${test}"
  date_began=$(sed -n -e '/^Began/s/.*:[  ]//p' ${test})
  date_finished=$(sed -n -e '/^Finished/s/.*:[  ]//p' ${test})
  time_delta=$(date -d @$(( $(date -d "${date_finished}" +%s) - $(date -d "${date_began}" +%s) )) -u +'%H:%M:%S')
  full_maxwrite=$(sed -n -e '/^Max Write:/s/.*:[   ]*\(.*\)$/\1/p' ${test})
  	num_maxwrite=$(echo $full_maxwrite | awk '{print $1}')
  units_maxwrite=$(echo $full_maxwrite | awk '{print $2}')
  full_maxread=$(sed -n -e '/^Max Read:/s/.*:[   ]*\(.*\)$/\1/p' ${test})
  	num_maxread=$(echo $full_maxread | awk '{print $1}')
  units_maxread=$(echo $full_maxread | awk '{print $2}')
  full_filesystem=$(sed -n -e '/^Path[  ]*:/s/.*:[   ]*\(.*\)$/\1/p' ${test})
		short_filesystem=$(echo ${full_filesystem} | sed -n -e 's,/p/\(.*\)/.*,\1,p')
  full_commandline=$(sed -n -e '/^Command line[  ]*:/s/.*:[   ]*\(.*\)$/\1/p' ${test})
	machine=$(sed -n -e '/^Machine[  ]*:/s/.*:[   ]*\(.*\)$/\1/p' ${test})
	api=$(sed -n -e '/^api[  ]*:/s/.*:[   ]*\(.*\)$/\1/p' ${test})
	access=$(sed -n -e '/^access[  ]*:/s/.*:[   ]*\(.*\)$/\1/p' ${test})
	type_of_io=$(sed -n -e '/^type[  ]*:/s/.*:[   ]*\(.*\)$/\1/p' ${test})
	segments=$(sed -n -e '/^segments[  ]*:/s/.*:[   ]*\(.*\)$/\1/p' ${test})
	ordering_in_a_file=$(sed -n -e '/^ordering in a file[  ]*:/s/.*:[   ]*\(.*\)$/\1/p' ${test})
	ordering_inter_file=$(sed -n -e '/^ordering inter file[  ]*:/s/.*:[   ]*\(.*\)$/\1/p' ${test})
	task_offset=$(sed -n -e '/^task offset[  ]*:/s/.*:[   ]*\(.*\)$/\1/p' ${test})
	nodes=$(sed -n -e '/^nodes[  ]*:/s/.*:[   ]*\(.*\)$/\1/p' ${test})
	tasks=$(sed -n -e '/^tasks[  ]*:/s/.*:[   ]*\(.*\)$/\1/p' ${test})
	clients_per_node=$(sed -n -e '/^clients per node[  ]*:/s/.*:[   ]*\(.*\)$/\1/p' ${test})
	repetitions=$(sed -n -e '/^repetitions[  ]*:/s/.*:[   ]*\(.*\)$/\1/p' ${test})
	xfersize=$(sed -n -e '/^xfersize[  ]*:/s/.*:[   ]*\(.*\)$/\1/p' ${test})
	blocksize=$(sed -n -e '/^blocksize[  ]*:/s/.*:[   ]*\(.*\)$/\1/p' ${test})
	aggregate_filesize=$(sed -n -e '/^aggregate filesize[  ]*:/s/.*:[   ]*\(.*\)$/\1/p' ${test})
	testid=$(sed -n -e '/^TestID[  ]*:/s/.*:[   ]*\(.*\)$/\1/p' ${test})
	FS=$(sed -n -e '/^FS[  ]*:/s/^FS[ 	]*:\(.*\)$/\1/p' ${test})
	filer_space=$(echo ${FS} | sed -n -e 's/\(.*\)[ 	]*Used FS.*$/\1/p')
	filer_space_used_percent=$(echo ${FS} | sed -n -e 's/.*Used FS: \([0-9.%]*\)[ 	]*Inodes.*$/\1/p')
	filer_inodes=$(echo ${FS} | sed -n -e 's/.*Inodes: \(.*\)[ 	]*Used Inodes.*$/\1/p')
	filer_inode_used_percent=$(echo ${FS} | sed -n -e 's/.*Used Inodes:[ 	]*\([0-9.%]*\).*$/\1/p')
	benchmark_name=$(sed -n -e '/^IOR-.*:/s/\(.*\):.*$/\1/p' ${test})
	benchmark_description=$(sed -n -e '/^IOR-.*:/s/.*:[   ]*\(.*\)$/\1/p' ${test})

  echo -en "${test}\t" | tee -a ${csvfile}
	echo -en "${num_maxwrite}\t" | tee -a ${csvfile}
	echo -en "${num_maxread}\t" | tee -a ${csvfile}
	echo -en "${time_delta}\t" | tee -a ${csvfile}
	echo -en "${date_began}\t" | tee -a ${csvfile}
	echo -en "${date_finished}\t" | tee -a ${csvfile}
	echo -en "${units_maxwrite}\t" | tee -a ${csvfile}
	echo -en "${units_maxread}\t" | tee -a ${csvfile}
	echo -en "${full_filesystem}\t" | tee -a ${csvfile}
	echo -en "${full_commandline}\t" | tee -a ${csvfile}
	echo -en "${machine}\t" | tee -a ${csvfile}
	echo -en "${api}\t" | tee -a ${csvfile}
	echo -en "${access}\t" | tee -a ${csvfile}
	echo -en "${type_of_io}\t" | tee -a ${csvfile}
	echo -en "${segments}\t" | tee -a ${csvfile}
	echo -en "${ordering_in_a_file}\t" | tee -a ${csvfile}
	echo -en "${ordering_inter_file}\t" | tee -a ${csvfile}
	echo -en "${task_offset}\t" | tee -a ${csvfile}
	echo -en "${nodes}\t" | tee -a ${csvfile}
	echo -en "${tasks}\t" | tee -a ${csvfile}
	echo -en "${clients_per_node}\t" | tee -a ${csvfile}
	echo -en "${repetitions}\t" | tee -a ${csvfile}
	echo -en "${xfersize}\t" | tee -a ${csvfile}
	echo -en "${blocksize}\t" | tee -a ${csvfile}
	echo -en "${aggregate_filesize}\t" | tee -a ${csvfile}
	echo -en "${testid}\t" | tee -a ${csvfile}
	echo -en "${short_filesystem}\t" | tee -a ${csvfile}
#	echo -en "${FS}\t" | tee -a ${csvfile}
	echo -en "${filer_space}\t" | tee -a ${csvfile}
	echo -en "${filer_space_used_percent}\t" | tee -a ${csvfile}
	echo -en "${filer_inodes}\t" | tee -a ${csvfile}
	echo -en "${filer_inode_used_percent}\t" | tee -a ${csvfile}
	echo -en "${benchmark_name}\t" | tee -a ${csvfile}
	echo -en "${benchmark_description}\t" | tee -a ${csvfile}
#	echo -en "${xxxx}\t" | tee -a ${csvfile}
	echo -en "\r\n" | tee -a ${csvfile}
done
