#!/bin/bash
set -x
if [ $# -lt 1 ]
then
	filesystem=/p/lustre3
else
	filesystem=$1
fi
cd ${filesystem}/${USER}
git clone https://github.com/spack/spack
cd spack
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
