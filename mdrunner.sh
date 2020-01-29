#!/bin/bash   
################################################################################
# Author: Robert E. Novak
# email: novak5@llnl.gov, sailnfool@gmail.com
#
# Run the ior script repeatedly across a set of processors.  The initial
# implementation takes the list of CPU sets as a command line option, E.G.:
#
# iorunner 10 20 40 80
#
# Future versions could run linear, fibonacci or exponential sequences.
# Rather than generate these sequences in this script, it would be preferable
# to generate those sequences as external command(s) that return those sequences
# with low and high limits, E.G.:
#
# iorunner $(fibonacci 1 $(nproc --show))
# iorunner $(linear -low 10 -increment 10 -high $(nproc --show))
#
################################################################################
source func.errecho
source func.insufficient
USAGE="${0##*/} [-hdv] [-f <filesystem>] [-m #] [-N #] -t <time> <#cpus1> <#cpus2> ...\r\n
\t\trun the mdtest benchmark with default options\r\n
\t-h\tPrint this message\r\n
\t-v\tSet verbose mode. If set before -h you get verbose help\r\n
\t-d\t#\tturn on diagnostics level #\r\n
\t-f\t<filesystem>\trun mdtest against the named filesystem/\$USER\r\n
\t-p\t#\tthe minimum percentage of nodes to distribute the load across\r\n
\t-N\t#\tthe number of nodes that you want to run on.\r\n
\t-t\t#\tthe number of minutes of CPU time you want to request\r\n"
VERBOSE_USAGE="${0##*/} Debugging, time infor and default information\r\n
\t-d\t8\tTurns on the bash \"set -x\" flag.\r\n
\t-d\t6\tRuns this script in testing mode to show what would run but\r\n
\t\t\tnot actually run.\r\n
\t-f\t<fs>\tdefaults to a file system of /p/lustre3\r\n
\t-t\r<minutes>\tActually just passes through to srun. Defaults to\r\n
\t\t\tone minute. See -t or --time so see all of the different options\r\n
\t\t\tlike min:sec\r\n"
NUMARGS=1
debug=0
filesystem=/p/lustre3
MinNodesPercent=25
MinNodesDivisor=`expr 100 '/' ${MinNodesPercent}`
testing=FALSE
memlimit=FALSE
NODES=""
setnodes=FALSE
sruntime=1
verbose=FALSE
#optionargs="hd:f:m:N:"
optionargs="hvt:d:f:p:N:"

while getopts ${optionargs} name
do
	case $name in
		d)
			FUNC_DEBUG=${OPTARG} # see func.errecho
			debug=${OPTARG}
			if [ ${debug} -gt 8 ]
			then
				set -x
			fi
			if [ ${debug} -gt 6 ]
			then
				testing=TRUE
			fi
			;;
		v)
			verbose=TRUE
			;;
    h)
			echo -en ${USAGE}
			if [ "${verbose}" = "TRUE" ]
			then
				echo -en ${VERBOSE_USAGE}
			fi
			exit 0
			;;
		f)
			filesystem=${OPTARG}
			;;
		p)
			MinNodesDivisor=`expr 100 '/' ${OPTARG}`
			;;
		N)
			NODES=${OPTARG}
			setnodes=TRUE
			;;
		t)
			sruntime=${OPTARG}
			;;
		\?)
			errecho "-e" ${LINENO} "invalid option: -$OPTARG"
			errecho "-e" ${LINENO} ${USAGE}
			exit 1
			;;
	esac
done
starttime=$(date -u "+%Y%m%d.%H%M%S")
shift $((OPTIND-1))
echo "${0##*/} ${LINENO} Found Arg count left is $#"
if [ $# -lt ${NUMARGS} ]
then
	errecho "-e" ${LINENO} ${USAGE}
	insufficient ${LINENO} ${FUNCNAME} ${NUMARGS} $@
fi

testcounts=""
if [ "${testing}" = "FALSE" ]
then
	for i in $*
	do
		testcounts="${testcounts} $i"
	done
	#testcounts="10 20 40 80"
else
	testcounts="1"
fi
echo "${0##*/} ${LINENO} testcounts=${testcounts}"
mdopts="-b 2 -z 3 -I 10"
mdbin=$HOME/tasks/ior/install.ior/bin/mdtest
mdtestdir=$HOME/tasks/ior/install.ior/testdir
filesystembasename=`basename ${filesystem}`
mkdir -p ${mdtestdir} ${mdtestdir}/${starttime}
if [ "${debug}" -ge 9 ]
then
	exit ${debug}
fi
for numprocs in ${testcounts}
do
	MinNodes=`expr ${numprocs} '/' ${MinNodesDivisor}`
	errecho ${LINENO} ${FUNCNAME} "MinNodes=${MinNodes}"
	if [ "${setnodes}" = "FALSE" ]
	then
		NODES=${MinNodes}
	fi
	if [ ${NODES} -eq 0 ]
	then
		NODES=1
	fi
	NODESTRING="$(printf "%03d" ${NODES})"
	PROCSTRING="$(printf "%03d" ${numprocs})"
	testnamesuffix=""
	testnamesuffix="${testnamesuffix}_N_${NODESTRING}_p_${PROCSTRING}_t_${sruntime}"
	mdtestname="${starttime}/md.${filesystembasename}_${testnamesuffix}"
# srun -n ${numprocs} -N ${NODES} -t ${sruntime} ${mdbin} ${mdopts} \
# 		-d ${filesystem}/$USER/tmp | \
# 		tee ${mdtestdir}/${mdtestname}.txt
 	echo "srun -n ${numprocs} -N ${NODES} -t ${sruntime} ${mdbin} ${mdopts} \
		-d ${filesystem}/$USER/tmp | \
		tee ${mdtestdir}/${mdtestname}.txt"
	if [ ${testing} = "FALSE" ]
	then
  	srun -n ${numprocs} -N ${NODES} -t ${sruntime} ${mdbin} ${mdopts} \
			-d ${filesystem}/$USER/tmp | \
			tee ${mdtestdir}/${mdtestname}.txt
	fi
done
exit 0
