#!/bin/bash
########################################################################
# Author Robert E. Novak
# email: novak4@llnl.gov, sailnfool@gmail.com
#
# Run a minimal test of spack.  This was enough to illustrate that
# some NFS capabilities had NOT been turned on in a file server.
########################################################################
if [ $# -lt 1 ]
then
	filesystem=/p/vast1
else
	filesystem=$1
fi
cd ${filesystem}/${USER}
git clone https://github.com/spack/spack
cd spack
git checkout releases/v0.13
source share/spack/setup-env.sh
echo $PATH
spack install libsigsegv
