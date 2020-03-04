
list_dobatch_md [-[hv]] -r <list?.txt> -f <list?.txt> -p <list?.txt>
 	-h		Print this help information
 	-v		Turn on verbose mode (works for -h: list_dobatch_md -v -h)
 	-f	<#>	retrieves /g/g0/novak5/tasks/scripts/etc/md.f.<#>....txt for
 			a list of the filesystems that will be tested. These should
 			all be mpi filesystems.
 	-r	<#>	retrieves /g/g0/novak5/tasks/scripts/etc/md.r.<#>....txt for a
 			list of the iorrunner commands (with options) that will
 			be run as tests.
 	-o	<#>	retrieves /g/g0/novak5/tasks/scripts/etc/md.o.<#>....txt for the
 			options sent to mdtest due to a problem of putting them
 			into runner
 	-p	<#>	retrieves /g/g0/novak5/tasks/scripts/etc/md.p.<#>i....txt for a
 			list of the number of processes that will be requested
 			when running iorrunner. Note that number of processes
 			and -p <percentage> of nodes to processes. Slightly
 			confusing, see -vh
list_dobatch_md Make sure you see md_runner -h and -vh
 		The set of all files for filesystems, md_runner commands
 		and process lists are found by 'ls ior.\*.list\*.txt'
 		this is highly useful if you want to perform
 		comparison of lustre1 to lustre3 or any other
 		sets of filesystems.
 
 		Default runner list = md_runner -x mi25 -p10
 		Default filesystem list = /p/lustre3
 		Default process list = 10
 		default option list = -i 5
