#!/bin/bash
########################################################################
# Author: Robert E. Novak
# email: novak5llnl.gov, sailnfool@gmail.com
#
# Set up global definitions of debugging levels
########################################################################
####################
# set the debug level to zero
# Define the debug levels:
#
# DEBUGSETX - turn on set -x to debug
# DEBUGNOEXECUTE - generate and display the command lines but don't
#                  execute the benchmark
####################
if [ -z "${__funcdebug}" ]
then
  export DEBUGOFF=0
  export DEBUGSETX=9
  export DEBUGNOEXECUTE=6
fi # if [ -z "${__funcdebug}" ]
