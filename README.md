iorscripts

These scripts are used to run the IOR Benchmark and the mdtest
benchmark on MPI class of systems and compare IO and metadata 
rates on a filesystem.

All of the top level scripts support a "-h" option to describe the
USAGE of the commands (in lieu of man pages).

These scripts have evolved over time.  The following notes may be
instructive.

The lowest level commands are:

ior_runner  and  md_runnner

These two commands are almost identical in their format and structure.
It may be instructive to look at:

func.global.sh

This contains definitions of Variables/Strings that are both
common and different between these commands.  As time moves on I
am attempting to coalesce these two commands into a single command.

Both of these commands will place their output into a directory.
The directory always has a unique name that reflects both the 
date/time that the benchmarks were run and the instance number of
the invocation of either command.

Note that both commands also log all of the steps in running each
instance of one of the benchmark and places them in a testlog.txt
file.  You can examine this file to see if any instances of the 
benchmark failed.

The major difference between the commands is the need for a "cleanup"
to occur in the md_runner.  A previous instance of md_runner may
have left the parent of a directory tree inside the file system 
under test.  That directory tree had the default path name of:

<filesystem>/${USER}/md.seq

however, since it could take up to 24 hours to delete that directory
tree from the filesystem, the path was changed to:

<filesystem>/${USER}/md.seq.$$

The process ID is appended to the end of the directory name.  When
a new instance starts, it will perform a cleanup of any old
copies of the directories AFTER insuring that there are not any
still living processes that may be working on the tree.  See 
md_cleanup.sh

The removal process can be up to 24 hours, so this cleanup process
is run as a background task.  Since the directory names are now
unique, failure to clean up in real time is not a problem unless
the file system inode and/or file space quotas are exceeded.

######################################################################

Necessary Supporting Files:
There are supplementary BASH functions which can be found at:

https://github.com/sailnfool/func

These functions need to be installed in you $HOME/bin to allow
all of these scripts to function.

######################################################################

Performing batch processing.  In order to run a series of benchmark
tests with varying numbers of parameters, processes, filesystems,
etc., you will want to become familiar with:

list_dobatch_ior  and  list_dobatch_md

These commands will pull in the parameters from a series of files
found in an etc directory.  See the "-h" for each command and look
at the sample files found in the etc directory to get a feel for 
how these work.

These commands will create a parent directory for each set of tests
that will contain the word BATCH in the directory as well as a
unique batch number.

Each of the parameter files which are used in the invocation of the
"runner" commands also are not only copied into the BATCH directory
but are postpended to the directory name to provide a mnemonic for
the parameter used in a BATCH set of tests.

At the end of a BATCH of tests, the log data for this BATCH is 
copied from the common logfile and placed within the batch directory.

The extraction scripts:

extract_ior  and  extract_md

are run at the end of the batch to figure take all of the data from 
the individual benchmark ascii text files and place the result of
each run in a Comma Separated Values (.csv) file suitable for loading
into a spreadsheet application like Microsoft MS-Office Excel or
Libreoffice Calc to analyze and graph the data.

Note that the new command:

do_extract

when run in the environment of a batch directory will figure out
which bencmark was run and run the correct extraction program to
create the .csv file.

######################################################################
LAST, but not least, each of the batch commands examines the 
log entries for each of the benchmarks run in this batch.  It 
performs a simple grep for FAIL.

The good news is that if your failure was due to time exceeded, 
each time that one of the "runner" scripts detects a failure
it will bump the default amount of time to run the benchmark,
so that quite often if you get time exceeded, a re-run will 
consult the procrate.txt file and see that the time has been 
increased so that a subsequent run should succeed.
######################################################################
