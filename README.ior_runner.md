
ior_runner [-hdDvc] [-f <filesystem>] [-m #] [-N #] 

		-t <minutes> -x <partition> <#procs> ...



		run the ior benchmark with default options provide a list

		of the number of processes.  See -p to control the # of nodes

		relative to the number of processes.

	-h	Print this message

	-v	Set verbose mode. If set before -h you get verbose help

	-a	<opt>	Additional options to add to the default set

	-c	Save output in CSV format

	-d	#	turn on diagnostics level #

	-f	<filesystem>	run ior against the named filesystem/$USER

	-m	#	the percentage of free memory to pre-allocate to avoid

			read cache problems

	-o	<opts>	replacement options to be passed directly to the

			benchmark

	-p	#	the number of processes per Node

	-N	#	the number of nodes that you want to run on.

		This is a hard coded number.  The numprocs will be distributed

		across this set of nodes.

		If not specified, it will be numprocs / processes per node

	-s	Assemble the requested runs as SBATCH scripts and place

		in the BATCH directory

	-t	#	the number of minutes of CPU time you want to request

	-x	<partition>	the name of a partition (subset of nodes on

			an MPI machine) (srun/sbatch dependent)
ior_runner Debugging, time information and

		default information

	-d	8	Turns on the bash "set -x" flag.

	-d	6	Runs this script in testing mode to show what would run

			but not actually run.

	-f	<fs>	defaults to a file system of /p/lustre3

	-t	<minutes>	Actually just passes through to srun. Defaults to

		one minute.

		There is now a complex system that attempts to

		track past usage to predict the number of milliseconds each

		process will need to run.



			Default Process Rate and Increase Percentage



		The default tables are kept in the etc subdirectory of

		testdir and end in \*.default.txt  The prefix of the name is

		the uppercase name of the test (e.g., IOR) followed by

		the name of the file system under test. E.G.:



			testdir/etc/IOR.lustre3.default.txt



		The content of the file is three numbers separated by

		vertical pipe "|" characters.  The first number is the

		band of the number of processes.  E.G., 100 represents

		than this is used for 1 to 100 processes, 200 for 101-200

		and so on.



		The second number is a guess of the number of milliseconds

		each process will need to run to completion. Don't worry

		if your guess is too low or if you forget to enter this

		file at all.  If you do a default one is created.


		The third number is the percentage by which the

		previously estimated time is increased if the benchmark

		failed due to exceeding estimated time.  A new GUESS

		row is created with a larger estimate for the next run,



		A sample:



			100|300|20



			Procrate Table



		A process rate table keeps track of the GUESSED and

		OBSERVED process rates for running the benchmark.

		The table is kept in:



		testdir/etc/IOR.lustre3.procrate.txt



		The procrate table contains 5 entries separated by "|"

			1) The band of the number of processes that this tracks

			     (as above), 100 represents 1-100 processes

			2) The low GUESSED/OBSERVED milliseconds per process.

			     This number is initially guessed at the same value as

			     the HIGH miliseconds per process.  It is never increased

			     by an OBSERVED value, only decreased.

			3) The high number of milliseconds.  This value is only

			     increased by either OBSERVED values or by a new GUESS.

			4) OBSERVED/GUESS marks that this row was created by

			     either an initial GUESS (see default.txt above) or by

			     a replacement row where the GUESS high value is

			     increased by the percentage in the default.txt table.

			5) The lowest OBSERVED high value.  This always starts

			     at zero (0) with a guess and keeps increasing.



		A sample: (assuming the prior run timed out!)



			100|250|10000|GUESS|7500



			Benchmark Run number



		This script keeps a running count of how many times the script

		has been run and uses that number in naming the directory in

		which the results are placed.  It uses a lock file to prevent

		multiple instances of the from updating the count

		inconsistently.  If you see the script spinning on the lock

		file, you may have to kill the script and manually remove the

		lock file from testdir



			BATCH Number



		If the invoking script has defined the environment variable

		batchstring, then each benchmark run result will be

		place in a batch directory rather than standalone in

		testdir
