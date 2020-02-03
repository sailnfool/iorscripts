#!/bin/bash
####################
# when we built ior, it was placed in a directory relative to the
# home directory.
####################
iorhomedir=$HOME/tasks/ior

####################
# the directory where binaries (bin) and libraries (lib) were placed
####################
iorinstalldir=${iorhomedir}/install.ior

####################
# where the ior bin (exec) file is found
####################
iorbindir=${iorinstalldir}/bin

####################
# we will place the testing directory at the same level as the installation
# directory, not as a subset of the installation.
####################
iortestdir=$(realpath ${iorinstalldir}/../testdir)
ioretcdir=${iortestdir}/etc

mkdir -p ${iortestdir} ${ioretcdir}

####################
# Create a lock file so that two different scripts don't update the test
# number
####################
while [ -f ${ioretcdir}/lock ]
do
	errecho ${LINENO} "Sleeping on lock acquistion for lock owned by"
	errecho ${LINENO} "$(ls -l ${ioretcdir}/lock*)"
	sleep 1
done
touch ${ioretcdir}/{lock,lock_process_${USER}_$$}

####################
# Use a file to keep track of the number of tests that have been run by this 
# script against the executable.
####################
iorbatchnumberfile=${ioretcdir}/IOR.BATCHNUMBER

####################
# if it does not exist, initialize it with a zero value
# otherwise retrieve the number in the file.
####################

if [ ! -f ${iorbatchnumberfile} ]
then
	iorbatchnumber=0
else
	iorbatchnumber=$(cat ${iorbatchnumberfile})
fi

####################
# bump the test number and stuff it back in the file.
####################
((++iorbatchnumber))
echo ${iorbatchnumber} > ${iorbatchnumberfile}

####################
# retrieve the current test number and stuff it in a test string for
# identifying the results directory
####################
mdbatchstring="${USER}-BATCH-$(printf '%04d' ${iorbatchnumber})"

####################
# Now we can release the lock and the lock info
####################
rm -f ${ioretcdir}/{lock,lock_process_${USER}_$$}

export mdbatchstring
if [ ! -r ${ioretcdir}/ior.list ]
then
	if [ -r ~/tasks/scripts/ior.list ]
	then
		cp ~/tasks/scripts/ior.list ${ioretcdir}/ior.list
	else
		errecho ${FUNCNAME} ${LINENO} "Could not find list of process numbers ior.list"
		exit 1
	fi
fi
for procnum in $(cat ${ioretcdir}/ior.list)
do
	proclist="${proclist} ${procnum}"
done
for filesystem in "/p/lustre3" "/p/vast1"
do
	echo "md_runner -x mi25 -f ${filesystem} -p 50 ${proclist}"
	md_runner -x mi25 -f ${filesystem} -p 50  ${proclist}
	echo "md_runner -x mi25 -f ${filesystem} -p 10 ${proclist}"
	md_runner -x mi25 -f ${filesystem} -p 10  ${proclist}
done
