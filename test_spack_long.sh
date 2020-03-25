#!/bin/bash
########################################################################
# Author Robert E. Novak
# email: novak5@llnl.gov, sailnfool@gmail.com
#
# Run a number of iterations of the "test_spack_core" script on a
# specified file system.
########################################################################
source func.errecho
set -x
runner_optionargs="chtf:r:"
filesystem=/p/lustre3
want_cleanup="FALSE"
USAGE="${0##*/} [-[ch]] [-f <filesystem>] \r\n
\t-h\t\tPrint this message\r\n
\t-c\t\tClean out any old copies of spack before running this test\r\n
\t\t\tTypically this is used when testing multiple runs to minimize\r\n
\t\t\tthe build/compile impact on a spack run and hopefully exercise\r\n
\t\t\tthe metdata process of building the requested componnents.\r\n
\t-f\t<filesystem>\tspecify the filesystem that spack will be tested\r\n
\t\t\ton.\r\n
\t-t\t\tCreate a directory in the filesystem and export TMPDIR to \r\n
\t\t\tto point to it.\r\n"
while getopts ${runner_optionargs} name
do
	case ${name} in
		c)
			want_cleanup="TRUE"
			;;
		f)
			filesystem="${OPTARG}"
			;;
		r)
			repetition="${OPTARG}"
			;;
		t)
			want_tmp="TRUE"
			;;
		\?)
			errecho "${0##*/}" ${LINENO} "invalid option: ${OPTARG}" >&2
			errecho "${USAGE}"
			exit 1
			;;
	esac
done
####################
# skip past the optional arguments processed above.
####################
shift $((OPTIND-1))

if [ "${filesystem}" = "${HOME}" ]
then
	fsbase="NFS"
else
	fsbase=${filesystem##*/}
fi
trycount=1

mkdir -p ${filesystem}/$USER
cd ${filesystem}/$USER
mkdir -p ${filesystem}/$USER/tmp
export TMPDIR=${filesystem}/${USER}/tmp

if [ "${want_cleanup}" = "TRUE" ]
then
	echo "${0##*/} Starting Cleanup $(date)"
	rm -rf spack
	echo "${0##*/} Finish Cleanup $(date)"
	echo "${0##*/} Starting clone $(date)"
	git clone https://github.com/spack/spack
	echo "${0##*/} Finish clone $(date)"
fi
cd spack
resultdir=${HOME_RESULTS}/${batchstring}
mkdir -p ${resultdir}
while [ ${trycount} -le ${repetition} ]
do
	count2d=$(printf '%02d' ${trycount})
	repetition2d=$(printf '%02d' ${repetition})
	spackresultfilename="spack_${fsbase}_${count2d}_of_${repetition2d}.txt"
	echo "${0##*/} Starting ${spackresultfilename}"
	/usr/bin/time test_spack_core 2>&1 | \
		tee ${resultdir}/${spackresultfilename}
	((++trycount))
	echo "${0##*/} finished ${spackresultfilename}"
done
