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
iortestdir=${iorinstalldir}/../testdir

####################
# If the test directory is not yet created, then make it.
####################
if [ ! -d ${iortestdir} ]
then
	mkdir -p ${iortestdir}
fi

####################
# Create a lock file so that two different scripts don't update the test
# number
####################
while [ -f ${iortestdir}/lock ]
do
	errecho ${LINENO} "Sleeping on lock acquistion for lock owned by"
	errecho ${LINENO} "$(ls -l ${iortestdir}/lock*)"
	sleep 1
done
touch ${iortestdir}/lock
touch ${iortestdir}/lock_process_${USER}_$$

####################
# Use a file to keep track of the number of tests that have been run by this 
# script against the executable.
####################
iorbatchnumberfile=${iortestdir}/IOR.BATCHNUMBER

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
iorbatchstring="${USER}-BATCH-$(printf '%04d' ${iorbatchnumber})"

####################
# Now we can release the lock and the lock info
####################
rm -f ${iortestdir}/lock_process_${USER}_$$
rm -f ${iortestdir}/lock

export iorbatchstring
for procnum in $(cat ~/tasks/scripts/ior.list)
do
	proclist="${proclist} ${procnum}"
done
#for filesystem in "/p/lustre3" "/p/vast1"
for filesystem in "/p/vast1"
do
	echo "iorunner -f ${filesystem} -p 50 -o "-Y" ${proclist}"
	iorunner -f ${filesystem} -p 50  -o "-Y" ${proclist}
	echo "iorunner -f ${filesystem} -p 10 -o "-Y" ${proclist}"
	iorunner -f ${filesystem} -p 10  -o "-Y" ${proclist}
done
