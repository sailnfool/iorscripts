#!/bin/bash
#echo -en "${test}\t$(awk '/^Command Line/ {Print}')\r\n"
echo -en "Test Name\tStart Time\tEnd Time\tMax Write\tMax Read\r\n"
for test in $*
do
  testname="${test}"
  #time_began=$(sed -e '/^Began/s/.*\([0-9][0-9]:[0-9][0-9]:[0-9][0-9]\).*/\1/' ${test})
  #began=$(awk '/^Began/ {print}' ${test} | sed -e '/^Began/s/.*\([0-9][0-9]:[0-9][0-9]:[0-9][0-9]\).*/\1/')
  began=$(awk '/^Began/ {print}' ${test})
  time_finished=$(echo ${finished} | sed -e 's/.*\([0-9][0-9]:[0-9][0-9]:[0-9][0-9]\).*/\1/')
  finished=$(awk '/^Finished/ {print}' ${test})
  maxwrite=$(awk '/^Max Write:/ {print}' ${test})
  maxread=$(awk '/^Max Read:/ {print}' ${test})
  time_began=$(echo ${began} | sed -e 's/.*\([0-9][0-9]:[0-9][0-9]:[0-9][0-9]\).*/\1/')
  time_finished=$(echo ${finished} | sed -e 's/.*\([0-9][0-9]:[0-9][0-9]:[0-9][0-9]\).*/\1/')
  num_maxwrite=$(echo ${maxwrite} | sed -e 's/.*:[   ]*\([0-9.]*\)[  ]*.*/\1/')
  num_maxread=$(echo ${maxread} | sed -e 's/.*:[   ]*\([0-9.]*\)[  ]*.*/\1/')
  echo -en "${test}\t${time_began}\t${time_finished}\t${num_maxwrite}\t${num_maxread}\r\n"
done
