#!/bin/bash
########################################################################
# Author: Robert E. Novak
# email: novak5@llnl.gov, sailnfool@gmail.com
#
# This is the core of the spack utility testing that are the spack
# installation steps that will be measured.
#
# At this point we assume that the setup is complete and that we are in
# the directory <filesystem>/${USER}/spack
########################################################################
date
git checkout releases/v0.13
source share/spack/setup-env.sh
echo $PATH
spack install zlib
spack install zlib %clang
spack versions zlib
spack install zlib@1.2.8
spack install zlib @1.2.8 cppflags=-O3
spack find
spack find -lf
spack install tcl
spack install tcl ^zlib @1.2.8 %clang
spack install tcl ^/y52
spack find -ldf
spack install hdf5
spack install hdf5~mpi
spack install hdf5+hl+mpi
spack install hdf5+mpi ^mpich
spack install trilinos
spack install trilinos +hdf5 ^hdf5+hl+mpi ^mpich
date
