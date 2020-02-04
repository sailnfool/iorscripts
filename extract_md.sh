#!/bin/bash
source func.errecho
FUNC_VERBOSE=1
USAGE="${0##*/} [-vh] [-d #] [-c <tab file>] <ior files> ...\r\n
\t\tprocess a set of md output files to turn them into suitable\r\n
\t\tcomma separated values (.csv) which are actually <tab> separated.\r\n
\t-v\tverbose output. If specified before -h, you get more.\r\n
\t-h\tPrint this message.\r\n
\t-d\t#\tturn on diagnostics level #\r\n
\t-c\t<tab file>\tThe name of the file which will hold the\r\n
\t\tgenerated summaries which include a header file to explain\r\n
\t\tthe columns.  The default filename is /tmp/${0##*/}.$$.csv,\r\n
\t\ti.e. the \$\$process id is part of the file name.\r\n"
VERBOSE_USAGE="${0##*/} will be used in conjunction with mdrunner, a\r\n
\t\tscript that will run a series of tests against a file system with\r\n
\t\ta varying number of processes on systems.  This will produce the\r\n
\t\tmd files used as input. See \"mdrunner -h\" for\r\n
\t\tmore information.\r\n\r\n
\t\tThese files are suitable for loading into your favorite\r\n
\t\tspreadsheet program to create graphs.  Each line of output\r\r
\t\tis a summary of an md output file.  Multiple scripts are\r\n
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
echo -en "Benchmark\t" | tee -a ${csvfile} # num_maxwrite
echo -en "Bench Description\t" | tee -a ${csvfile} # num_maxread
echo -en "Bench Tasks\t" | tee -a ${csvfile} # benchmark_tasks
echo -en "Bench Nodes\t" | tee -a ${csvfile} # benchmark_nodes
echo -en "Test Duration\t" | tee -a ${csvfile} # time_delta
echo -en "Start Time\t" | tee -a ${csvfile} # date_began
echo -en "End Time\t" | tee -a ${csvfile} # date_finished
echo -en "Directory creation Max\t" | tee -a ${csvfile} # units_maxwrite
echo -en "Directory creation Min\t" | tee -a ${csvfile} # units_maxwrite
echo -en "Directory creation Mean\t" | tee -a ${csvfile} # units_maxwrite
echo -en "Directory creation Std Dev\t" | tee -a ${csvfile} # units_maxwrite
echo -en "Directory stat Max\t" | tee -a ${csvfile} # units_maxwrite
echo -en "Directory stat Min\t" | tee -a ${csvfile} # units_maxwrite
echo -en "Directory stat Mean\t" | tee -a ${csvfile} # units_maxwrite
echo -en "Directory stat Std Dev\t" | tee -a ${csvfile} # units_maxwrite
echo -en "Directory removal Max\t" | tee -a ${csvfile} # units_maxwrite
echo -en "Directory removal Min\t" | tee -a ${csvfile} # units_maxwrite
echo -en "Directory removal Mean\t" | tee -a ${csvfile} # units_maxwrite
echo -en "Directory removal Std Dev\t" | tee -a ${csvfile} # units_maxwrite
echo -en "File creation Max\t" | tee -a ${csvfile} # units_maxwrite
echo -en "File creation Min\t" | tee -a ${csvfile} # units_maxwrite
echo -en "File creation Mean\t" | tee -a ${csvfile} # units_maxwrite
echo -en "File creation Std Dev\t" | tee -a ${csvfile} # units_maxwrite
echo -en "File stat Max\t" | tee -a ${csvfile} # units_maxwrite
echo -en "File stat Min\t" | tee -a ${csvfile} # units_maxwrite
echo -en "File stat Mean\t" | tee -a ${csvfile} # units_maxwrite
echo -en "File stat Std Dev\t" | tee -a ${csvfile} # units_maxwrite
echo -en "File read Max\t" | tee -a ${csvfile} # units_maxwrite
echo -en "File read Min\t" | tee -a ${csvfile} # units_maxwrite
echo -en "File read Mean\t" | tee -a ${csvfile} # units_maxwrite
echo -en "File read Std Dev\t" | tee -a ${csvfile} # units_maxwrite
echo -en "File removal Max\t" | tee -a ${csvfile} # units_maxwrite
echo -en "File removal Min\t" | tee -a ${csvfile} # units_maxwrite
echo -en "File removal Mean\t" | tee -a ${csvfile} # units_maxwrite
echo -en "File removal Std Dev\t" | tee -a ${csvfile} # units_maxwrite
echo -en "Tree Creation Max\t" | tee -a ${csvfile} # units_maxwrite
echo -en "Tree Creation Min\t" | tee -a ${csvfile} # units_maxwrite
echo -en "Tree Creation Mean\t" | tee -a ${csvfile} # units_maxwrite
echo -en "Tree Creation Std Dev\t" | tee -a ${csvfile} # units_maxwrite
echo -en "Tree removal Max\t" | tee -a ${csvfile} # units_maxwrite
echo -en "Tree removal Min\t" | tee -a ${csvfile} # units_maxwrite
echo -en "Tree removal Mean\t" | tee -a ${csvfile} # units_maxwrite
echo -en "Tree removal Std Dev\t" | tee -a ${csvfile} # units_maxwrite
echo -en "File System\t" | tee -a ${csvfile} # full_filesystem
echo -en "filername\t" | tee -a ${csvfile} # short_filesystem
echo -en "Command Line\t" | tee -a ${csvfile} # full_commandline
echo -en "Repetitions\t" | tee -a ${csvfile} # repetitions
#echo -en "FS\t" | tee -a ${csvfile} # FS
echo -en "Filer Space\t" | tee -a ${csvfile} # filer_space
echo -en "Filer Space used %\t" | tee -a ${csvfile} # filer_space_used_percent
echo -en "Filer inodes\t" | tee -a ${csvfile} # filer_inodes
echo -en "Filer inode used %\t" | tee -a ${csvfile} # filer_inode_used_percent
# echo -en "yyyy\t" | tee -a ${csvfile} # xxxx
echo -en "\r\n" | tee -a ${csvfile}
for test in $*
do
	# We will read the output file many, many times because the data is not
	# in a form that is amenable for loading into a spreadsheet (e.g., csv)
  testname="${test}"
	date_md_began=$(sed -n -e '/^-- started/s/^-- started at.*[  ]\(.*\) --.*$/\1/p' ${test})
		date_began=$(date --date=${date_md_began})
	benchmark_name=$(sed -n -e '/^mdtest-/s/\(.*\) was launched.*/\1/p' ${test})
	benchmark_description=$(sed -n -e '/^mdtest-/s/.*was \(.*\)$/\1/p' ${test})
	benchmark_tasks=$(echo ${benchmark_description} | sed 's/^.*launched with[^0-9]*\([0-9][0-9]*\).*/\1/')
	benchmark_nodes=$(echo ${benchmark_description} | sed 's/^.*on \([0-9][0-9]*\).*$/\1/')
  full_commandline=$(sed -n -e '/^Command line used.*:/s/.*:[   ]*\(.*\)$/\1/p' ${test})
  full_filesystem=$(sed -n -e '/^Path[  ]*:/s/.*:[   ]*\(.*\)$/\1/p' ${test})
		short_filesystem=$(echo ${full_filesystem} | sed -n -e 's,/p/\(.*\)/.*,\1,p')
	FS=$(sed -n -e '/^FS[  ]*:/s/^FS[ 	]*:\(.*\)$/\1/p' ${test})
	filer_space=$(echo ${FS} | sed -n -e 's/\(.*\)[ 	]*Used FS.*$/\1/p')
	filer_space_used_percent=$(echo ${FS} | sed -n -e 's/.*Used FS: \([0-9.%]*\)[ 	]*Inodes.*$/\1/p')
	filer_inodes=$(echo ${FS} | sed -n -e 's/.*Inodes: \(.*\)[ 	]*Used Inodes.*$/\1/p')
	filer_inode_used_percent=$(echo ${FS} | sed -n -e 's/.*Used Inodes:[ 	]*\([0-9.%]*\).*$/\1/p')
	nodemap=$(sed -n -e '/^Nodemap/s/^Nodemap:[ ]*\(.*\)/\1/p' ${test})
	taskdir=$(sed -n -e '/^[0-9]*.*tasks,/p' ${test})
	numtasks=$(echo ${taskdir} | sed 's/^\([0-9]*\)[^0-9]* tasks,.*$/\1/')
	filedirs=$(echo ${taskdir} | sed 's/^.*tasks, *\([0-9]*\) files\/directories.*$/\1/')
	sumrate=$(sed -n -e '/^SUMMARY/s/^SUMMARY.*:.*of *\([0-9]*[^0-9]\).*$/\1/p' ${test})
	dircreate=$(sed -n -e '/^ *Directory creation/s/.*Directory creation.*:\(.*\)$/\1/p' ${test})
	errecho ${LINENO} ${FUNCNAME} "dircreate=${dircreate}"
	dircreate_max=$(echo ${dircreate}| awk -F " " '{print $1}')
	dircreate_min=$(echo ${dircreate}| awk -F " " '{print $2}')
	dircreate_mean=$(echo ${dircreate}| awk -F " " '{print $3}')
	dircreate_sdev=$(echo ${dircreate}| awk -F " " '{print $4}')
	dirstat=$(sed -n -e '/^ *Directory stat/s/.*Directory stat.*:\(.*\)$/\1/p' ${test})
	dirstat_max=$(echo ${dirstat}| awk -F " " '{print $1}')
	dirstat_min=$(echo ${dirstat}| awk -F " " '{print $2}')
	dirstat_mean=$(echo ${dirstat}| awk -F " " '{print $3}')
	dirstat_sdev=$(echo ${dirstat}| awk -F " " '{print $4}')
	dir_removal=$(sed -n -e '/^ *Directory removal/s/.*Directory removal.*:\(.*\)$/\1/p' ${test})
	dir_removal_max=$(echo ${dir_removal}| awk -F " " '{print $1}')
	dir_removal_min=$(echo ${dir_removal}| awk -F " " '{print $2}')
	dir_removal_mean=$(echo ${dir_removal}| awk -F " " '{print $3}')
	dir_removal_sdev=$(echo ${dir_removal}| awk -F " " '{print $4}')
	filecreate=$(sed -n -e '/^ *File creation/s/.*File creation.*:\(.*\)$/\1/p' ${test})
	filecreate_max=$(echo ${filecreate}| awk -F " " '{print $1}')
	filecreate_min=$(echo ${filecreate}| awk -F " " '{print $2}')
	filecreate_mean=$(echo ${filecreate}| awk -F " " '{print $3}')
	filecreate_sdev=$(echo ${filecreate}| awk -F " " '{print $4}')
	filestat=$(sed -n -e '/^ *File stat/s/.*File stat.*:\(.*\)$/\1/p' ${test})
	filestat_max=$(echo ${filestat}| awk -F " " '{print $1}')
	filestat_min=$(echo ${filestat}| awk -F " " '{print $2}')
	filestat_mean=$(echo ${filestat}| awk -F " " '{print $3}')
	filestat_sdev=$(echo ${filestat}| awk -F " " '{print $4}')
	fileread=$(sed -n -e '/^ *File read/s/.*File read.*:\(.*\)$/\1/p' ${test})
	fileread_max=$(echo ${fileread}| awk -F " " '{print $1}')
	fileread_min=$(echo ${fileread}| awk -F " " '{print $2}')
	fileread_mean=$(echo ${fileread}| awk -F " " '{print $3}')
	fileread_sdev=$(echo ${fileread}| awk -F " " '{print $4}')
	file_removal=$(sed -n -e '/^ *File removal/s/.*File removal.*:\(.*\)$/\1/p' ${test})
	file_removal_max=$(echo ${file_removal}| awk -F " " '{print $1}')
	file_removal_min=$(echo ${file_removal}| awk -F " " '{print $2}')
	file_removal_mean=$(echo ${file_removal}| awk -F " " '{print $3}')
	file_removal_sdev=$(echo ${file_removal}| awk -F " " '{print $4}')
	treecreate=$(sed -n -e '/^ *Tree creation/s/.*Tree creation.*:\(.*\)$/\1/p' ${test})
	treecreate_max=$(echo ${treecreate}| awk -F " " '{print $1}')
	treecreate_min=$(echo ${treecreate}| awk -F " " '{print $2}')
	treecreate_mean=$(echo ${treecreate}| awk -F " " '{print $3}')
	treecreate_sdev=$(echo ${treecreate}| awk -F " " '{print $4}')
	tree_removal=$(sed -n -e '/^ *Tree removal/s/.*Tree removal.*:\(.*\)$/\1/p' ${test})
	tree_removal_max=$(echo ${tree_removal}| awk -F " " '{print $1}')
	tree_removal_min=$(echo ${tree_removal}| awk -F " " '{print $2}')
	tree_removal_mean=$(echo ${tree_removal}| awk -F " " '{print $3}')
	tree_removal_sdev=$(echo ${tree_removal}| awk -F " " '{print $4}')
	date_md_finished=$(sed -n -e '/^-- finished/s/^-- finished at.*[  ]\(.*\) --.*$/\1/p' ${test})
	date_finished=$(date --date="${date_md_finished}")
  time_delta=$(date -d @$(( $(date -d "${date_finished}" +%s) - $(date -d "${date_began}" +%s) )) -u +'%H:%M:%S')
  echo -en "${test}\t" | tee -a ${csvfile}
	echo -en "${benchmark_name}\t" | tee -a ${csvfile}
	echo -en "${benchmark_description}\t" | tee -a ${csvfile}
	echo -en "${benchmark_tasks}\t" | tee -a ${csvfile}
	echo -en "${benchmark_nodes}\t" | tee -a ${csvfile}
	echo -en "${time_delta}\t" | tee -a ${csvfile}
	echo -en "${date_began}\t" | tee -a ${csvfile}
	echo -en "${date_finished}\t" | tee -a ${csvfile}
	echo -en "${dircreate_max}\t" | tee -a ${csvfile}
	echo -en "${dircreate_min}\t" | tee -a ${csvfile}
	echo -en "${dircreate_mean}\t" | tee -a ${csvfile}
	echo -en "${dircreate_sdev}\t" | tee -a ${csvfile}
	echo -en "${dirstat_max}\t" | tee -a ${csvfile}
	echo -en "${dirstat_min}\t" | tee -a ${csvfile}
	echo -en "${dirstat_mean}\t" | tee -a ${csvfile}
	echo -en "${dirstat_sdev}\t" | tee -a ${csvfile}
	echo -en "${dir_removal_max}\t" | tee -a ${csvfile}
	echo -en "${dir_removal_min}\t" | tee -a ${csvfile}
	echo -en "${dir_removal_mean}\t" | tee -a ${csvfile}
	echo -en "${dir_removal_sdev}\t" | tee -a ${csvfile}
	echo -en "${filecreate_max}\t" | tee -a ${csvfile}
	echo -en "${filecreate_min}\t" | tee -a ${csvfile}
	echo -en "${filecreate_mean}\t" | tee -a ${csvfile}
	echo -en "${filecreate_sdev}\t" | tee -a ${csvfile}
	echo -en "${filestat_max}\t" | tee -a ${csvfile}
	echo -en "${filestat_min}\t" | tee -a ${csvfile}
	echo -en "${filestat_mean}\t" | tee -a ${csvfile}
	echo -en "${filestat_sdev}\t" | tee -a ${csvfile}
	echo -en "${fileread_max}\t" | tee -a ${csvfile}
	echo -en "${fileread_min}\t" | tee -a ${csvfile}
	echo -en "${fileread_mean}\t" | tee -a ${csvfile}
	echo -en "${fileread_sdev}\t" | tee -a ${csvfile}
	echo -en "${file_removal_max}\t" | tee -a ${csvfile}
	echo -en "${file_removal_min}\t" | tee -a ${csvfile}
	echo -en "${file_removal_mean}\t" | tee -a ${csvfile}
	echo -en "${file_removal_sdev}\t" | tee -a ${csvfile}
	echo -en "${treecreate_max}\t" | tee -a ${csvfile}
	echo -en "${treecreate_min}\t" | tee -a ${csvfile}
	echo -en "${treecreate_mean}\t" | tee -a ${csvfile}
	echo -en "${treecreate_sdev}\t" | tee -a ${csvfile}
	echo -en "${tree_removal_max}\t" | tee -a ${csvfile}
	echo -en "${tree_removal_min}\t" | tee -a ${csvfile}
	echo -en "${tree_removal_mean}\t" | tee -a ${csvfile}
	echo -en "${tree_removal_sdev}\t" | tee -a ${csvfile}
	echo -en "${full_filesystem}\t" | tee -a ${csvfile}
	echo -en "${short_filesystem}\t" | tee -a ${csvfile}
	echo -en "${full_commandline}\t" | tee -a ${csvfile}
	echo -en "${sumrate}\t" | tee -a ${csvfile}
#	echo -en "${FS}\t" | tee -a ${csvfile}
	echo -en "${filer_space}\t" | tee -a ${csvfile}
	echo -en "${filer_space_used_percent}\t" | tee -a ${csvfile}
	echo -en "${filer_inodes}\t" | tee -a ${csvfile}
	echo -en "${filer_inode_used_percent}\t" | tee -a ${csvfile}
#	echo -en "${xxxx}\t" | tee -a ${csvfile}
	echo -en "\r\n" | tee -a ${csvfile}
done
