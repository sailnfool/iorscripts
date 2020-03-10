#!/bin/bash
########################################################################
# Author: Robert E. Novak
# email: novak5@llnl.gov, sailnfool@gmail.com
#
# This script runs the spack test for multiple iterations across
# multiple filesystems.  ${HOME} is used as a surrogate for the NFS
# file system since that is where the user's directory is placed.
########################################################################
source func.errecho
source func.global2
set -x
batchnumber=$(func_getbatchnumber)
batchstring="${USER}-BATCH-SPACK-$(printf '%04d' ${batchnumber})"
export batchstring
test_spack_long -c -r 3 -f /p/vast1
test_spack_long -c -r 3 -f /p/lustre3
test_spack_long -c -r 3 -f ${HOME}
