#!/bin/bash

# EM April 15, modified March 16

# modified May 18 for multiple instances

# TODO: option to start tasks and quit / quit if no more tasks
# TODO: printing for instance tasks
# TODO: keep track of running time and total time in current tasks file and tasks done file
# TODO: option slurm instead of additional script?
# TODO: make multi-daemon mode the default
# TODO: quiet option
# TODO: option to log everything to specific dir with name based on daemonId (see about tasks list files) "control dir"
# TODO: flexible management wrt time and memory
# TODO: option task splitting?
# TODO: option timeout tasks (by adding to the .running)
# TODO: option to die after a certain time and resubmit job for itself ???

# remark: analyze options about some kind of interactive mode (current, with regular printing) and silent mode with just control files

# TODO what to do if a job is killed (memory issue)? tasks left as "running" should not be restarted as they are potentially going to fail, but should not be counted as running anymore.

# outside this script: generate generic sbatch job, possibly with specific process which submits jobs in the queue to continue.

# TODO: task done should be removed from the dir, maybe store it somewhere else? debug option?

# TODO option randomize picking task, in order to avoid putting big tasks together

# default config with workdir/tasks workdir/control files??


source common-lib.sh
source file-lib.sh

startDate=$(date +"%y.%m.%d_%H.%M")
progName=$(basename "$BASH_SOURCE")
daemonId="$HOSTNAME-$$-$startDate"
workDir=
batchSize=1
runScript=""
taskInitCommand=""
nbSlots=
iterNo=
nbPrevDone=0
sleepTime=60s
waitAtLeastTimeAfterFileWritten=10 # to avoid moving a task file which is not finished to be written
summaryEveryNIterations=30
forceDeletePrevRunning=0
continueWithPrevRunning=0
verbose=0
printNbLastDone=10
debugDir=""
multiDaemons=""
lockSleepTime=5s
adaptMemByProcess=""
quitIdle=0


myCurrentTasksFile=$(mktemp --tmpdir "$daemonId.XXXXXXXXXX.running")
myTasksDoneFile=$(mktemp --tmpdir "$daemonId.XXXXXXXXXX.done")


function usage {
  echo
  echo "Usage: $progName [options] <work dir> <nb slots>"
  echo
  echo "  manages parallel tasks submitted in <work dir>:"
  echo "   - other programs write their tasks as files <task> (unique name) in <work dir>;"
  echo "   - when a slot is empty, <task> is renamed as <task>.runnning (and modified)."
  echo "   - when the task is done, <task> is renamed as <task>.done."
  echo
  echo "  Options:"
  echo "    -h this help"
  echo "    -s <sleep time> default: $sleepTime"
  echo "    -p <N> print summary every N iterations (i.e. N * <sleep time>)"
  echo "       default: $summaryEveryNIterations"
  echo "    -f force deletion of previously existing <task>.running files;"
  echo "       (ignored if -c or -m is supplied)."
  echo "    -c continue normally with previously existing <task>.running files"
  echo "       (-f is ignored; implied in multiple daemon mode, see -m)."
  echo "    -v verbose mode: more details about running processes printed"
  echo "    -V high verbose mode: prints info every time a task is started  (implies -v)"
  echo "    -b <N> start tasks by batches of <N> (useful with -e). Default: 1"
  echo "    -e <script> transmit every (batch of) task(s) to <script>, called like this:"
  echo "         <script> <tasks list file>"
  echo "       where <tasks list file> contains <M> tasks, one by line (M <=N, with <N> the"
  echo "       number of tasks per batch; see -b)."
  echo "       Important: the task file to run is <f>.running"
  echo "       Remark 1: <script> can be a full path or a script available in the envirnment "
  echo "               variable PATH."
  echo "       Remark 2: using quote arguments can be provided to the script, e.g.:"
  echo "                 -e 'script <arg1> <arg2>'"
  echo "                 (this can be used to transmit a path, for instance)."
  echo "    -i <task first command> add this command to be run before the task for every"
  echo "       task. Example: 'source ~/.bashrc'"
  echo "    -d <dir> debug mode: copy the '.processing' version of the task in this dir."
  echo "    -m Multiple daemons mode. Allows multiple instances of this script to work on"
  echo "       the same list of tasks while avoiding conflicts over tasks between instances."
  echo "    -a <mem by process (GB)> adapt the number of processes to run in parallel to"
  echo "       the machine; the number of processes is calculated as: "
  echo "         min ( <total memory>/<mem by process> , <nb cores> ,  <nb slots> )"
  echo "       i.e. the resulting number cannot be more than the actual number of cores or"
  echo "       the value given for <nb slots>. If <mem by process> is 0, then the minimum"
  echo "       between <nb cores> and <nb slots> is used."
  echo "    -q <N> exit after N iterations with all tasks done and no new task to do."
  echo
}


#
# if $2 is not empty, print in format HH:MM:SS
#
# caution: if a task finishes very quickly (e.g. error in parameters), there might
# be an error because the file doesn't exist anymore when we try to calculate
# its last modif time (unsure how this works actually). Error msg is:
# 
# date: : No such file or directory
# task-distrib-daemon.sh: line 50: 1431869554 -  : syntax error: operand expected (error token is "-  ")
#
#
function timeElapsedSinceFileWasModified {
    local f="$1"
    local hms="$2"
    if [ -f "$f" ]; then
	elapsedInSec=$(( $(date +%s) - $(date +%s -r "$f") ))
	if [ -z "$hms" ]; then
	    echo "$elapsedInSec"
	else
	    date -u -d @${elapsedInSec} +"%T" # from http://stackoverflow.com/questions/13422743/convert-seconds-to-formatted-time-in-shell
	fi
    else
	echo "Error: '$f' does not exist" 1>&2
	exit 5
    fi
}


#
# returns 3 values: nb waiting, nb running, nb done since the dameon was started
# use cut -f <X> to get a specific value
#
function getCurrentNbGlobal {
    # info: using a file because 'ls dir/*.done'  will sometimes give an error "argument list too long"
    # see also http://www.linuxjournal.com/article/6060?page=0,0
    tmp=$(mktemp) 
    ls "$workDir" | grep -v "lock" >"$tmp" 2>/dev/null
    nbAll=$(cat "$tmp" | wc -l)
    nbRunning=$(cat "$tmp" | grep '.running$' | wc -l)
    nbDoneAll=$(cat "$tmp" | grep '.done$' | wc -l)
    nbWaiting=$(( $nbAll - $nbDoneAll - $nbRunning ))
    nbDone=$(( $nbDoneAll - $nbPrevDone ))
#    echo -e "nbAll=$nbAll,nbRunning=$nbRunning,nbDoneAll=$nbDoneAll,nbWaitinng=$nbWaiting,nbDone=$nbDone" 1>&2
    echo -e "$nbWaiting\t$nbRunning\t$nbDone"
    rm -f "$tmp"
}


#
# the task must exist!
#
function getTask {
    local newOld="$1"
    local categ="$2"
    local nb="$3"

    if [ -z "$nb" ]; then
	nb=1
    fi
    if [ "$newOld" == "new" ]; then
	optLs=""
    elif [ "$newOld" == "old" ]; then
	optLs="-r"
    else
	echo "ERROR: invalid value '$newOld': must be 'new' or 'old'."
	exit 14
    fi
    # info: using grep because 'ls dir/*.done'  will sometimes give an error "argument list too long"
    # see also http://www.linuxjournal.com/article/6060?page=0,0
    comm1="ls -t $optLs \"$workDir\" 2>/dev/null"
    if [ "$categ" == "done" ]; then
	comm="$comm1 | grep '.done$' "
    elif [ "$categ" == "run" ]; then
	comm="$comm1 | grep '.running$' "
    elif [ "$categ" == "wait" ]; then
	comm="$comm1 | grep -v '.running$' | grep -v '.done$' "
    else
	echo "ERROR: invalid value '$categ': must be 'done', 'wait', or 'run'."
	exit 14
    fi

#    echo "$comm  | head -n $nb |  sed 's:^:$workDir:g'" 1>&2
    evalSafe "$comm  | grep -v lock | head -n $nb |  sed 's:^:$workDir/:g'" "$progName,$LINENO: "
}


function printSummary {
    nbWait=$1
    nbRun=$2
    nbDone=$3
    
    now=$(date +"%y.%m.%d %H:%M")
    echo "SUMMARY $now: $nbWait tasks waiting, $nbRun tasks running, $nbDone tasks done."
    if [ ! -z "$multiDaemons" ]; then
	myNbRun=$(cat "$myCurrentTasksFile" | wc -l)
	myNbDone=$(cat "$myTasksDoneFile" | wc -l)
	echo "  Daemon $daemonId: $myNbRun tasks running, $myNbDone tasks done since $startDate."
    fi
    if [ $nbRun -gt 0 ]; then
	f=$(getTask "old" "run")
	if [ ! -z "$f" ]; then # no file running currently (probably finished quickly)
	    s=$(timeElapsedSinceFileWasModified "$f" 1)
	    echo -n "          Oldest task running, started $s ago: "
	    basename "${f%.running}"
	    f=$(getTask "new" "run")
	    s=$(timeElapsedSinceFileWasModified "$f" 1)
	    echo -n "          Newest task running started $s ago: "
	    basename "${f%.running}"
	    if [ $verbose -ge 1 ]; then
		echo "        Currently running tasks:"
		getTask "new" "run" "$nbSlots" | while read f; do
		    s=$(timeElapsedSinceFileWasModified "$f" 1)
		    echo "          $(basename ${f%.running}) (started ${s} ago)"
		done
		
	    fi
	else 
	    echo    "          cannot print details, the $nbRun running task(s) are finished already"
	fi
    else
	echo "        no task running currently."
    fi
    echo "        Recently achieved tasks:"
    getTask "new" "done" "$printNbLastDone" | while read f; do
	s=$(timeElapsedSinceFileWasModified "$f" 1)
	echo "          $(basename ${f%.done}) (done $s ago)"
    done
}


function calculateNbSlots {
    local memByProcessGB="$1"

    nbCores=$(grep -c "^processor" /proc/cpuinfo)
#    echo "debug: nb cores = $nbCores" 1>&2
    nbProcesses=$nbSlots
    if [ $nbCores -lt $nbProcesses ]; then
	nbProcesses=$nbCores
    fi
    if [ $memByProcessGB -ne 0 ]; then
	# assuming mem always given in kb
	totalMemKB=$(cat /proc/meminfo | grep MemTotal | sed 's/^MemTotal:\s*//' | cut -f 1 -d ' ')
#	echo "debug: total memory = $totalMemKB" 1>&2
	memByProcessKB=$(( $memByProcessGB * 1024 * 1024 ))
	# remark: truncating to the nearest lower int
	nbMem=$(( $totalMemKB / $memByProcessKB ))
	if [ $nbMem -lt $nbProcesses ]; then
	    nbProcesses=$nbMem
	fi
    fi
    #echo "debug: final nb processes = $nbProcesses" 1>&2
    echo "$nbProcesses"
}



function updateRunningTasks {
    next=$(mktemp --tmpdir "$daemonId.next.XXXXXXXXXX")
    cat "$myCurrentTasksFile" | while read f; do
	if [ -f "$f.running" ]; then # still running
	    echo "$f" >>"$next"
	else
	    if [ -f "$f.done" ]; then
		echo "$f" >>"$myTasksDoneFile"
		if [ $verbose -ge 2 ]; then
                    echo "INFO: Finished task '$f'"
		fi
	    else
		echo "Warning: ghost task $f is neither running or done" 1>&2
	    fi
	fi
    done
    cat "$next" >"$myCurrentTasksFile"
    rm -f "$next"
}





OPTIND=1
while getopts 'vVhs:p:fcb:e:i:d:ma:q:' option ; do 
    case $option in
	"d" ) debugDir="$OPTARG";;
	"h" ) usage
 	      exit 0;;
	"s" ) sleepTime="$OPTARG";;
	"p" ) summaryEveryNIterations="$OPTARG";;
	"f" ) forceDeletePrevRunning=1;;
	"c" ) continueWithPrevRunning=1;;
	"v" ) verbose=1;;
	"V" ) verbose=2;;
	"b" ) batchSize="$OPTARG";;
	"e" ) runScript="$OPTARG";;
	"i" ) taskInitCommand="$OPTARG";;
	"m" ) multiDaemons="yep"
	      continueWithPrevRunning=1;;
	"a" ) adaptMemByProcess="$OPTARG";;
	"q" ) quitIdle="$OPTARG";;
	"?" ) 
	    echo "Error, unknow option." 1>&2
            printHelp=1;;
    esac
done
shift $(($OPTIND - 1))
if [ $# -ne 2 ]; then
    echo "Error: expecting 2 args." 1>&2
    printHelp=1
fi
if [ ! -z "$printHelp" ]; then
    usage 1>&2
    exit 1
fi
workDir="$1"
nbSlots="$2"

if [ ! -z "$adaptMemByProcess" ]; then
    echo -n "Calculating number of parallel processes for $daemonId (memory by process = $adaptMemByProcess) : "
    nbSlots=$(calculateNbSlots "$adaptMemByProcess")
    echo $nbSlots
fi

mkdirSafe "$workDir" "$progName,$LINENO: "

nbs=$(getCurrentNbGlobal)
nbPrevDone=$(echo "$nbs" | cut -f 3)
nbRun=$(echo "$nbs" | cut -f 2)
nbWait=$(echo "$nbs" | cut -f 1)
if [ $continueWithPrevRunning -ne 1 ]; then
    if [ $forceDeletePrevRunning -eq 1 ]; then
	rm -f "$workDir"/*.running
    else
	if [ $nbRun -gt 0 ]; then
	    echo "ERROR: there are $nbRun existing running tasks files in '$workDir'" 1>&2
	    echo "  Use -f to delete them or -c to continue with them." 1>&2
	    exit 4
	fi
    fi
else
    echo "INFO $nbRun previously running tasks" 
fi
if [ $nbWait -gt 0 ]; then
    echo "INFO $nbWait previously waiting tasks"
fi

if [ $verbose -ge 1 ]; then
    echo "INFO: current tasks file: $myCurrentTasksFile"
    echo "INFO: done tasks file: $myTasksDoneFile"
fi

iterNo=0
nbIterIdle=0
while [ $quitIdle == 0 ] || [ $nbIterIdle -lt $quitIdle ]; do
    nbs=$(getCurrentNbGlobal)
#    nbRun=$(echo "$nbs" | cut -f 2)
    nbWait=$(echo "$nbs" | cut -f 1)
    updateRunningTasks
    myNbRun=$(cat "$myCurrentTasksFile" | wc -l)
    if [ $myNbRun -eq 0 ]; then
	# assuming that the iteration is idle, reset later if not
	nbIterIdle=$(( $nbIterIdle + 1 ))
    else
	nbIterIdle=0
    fi

    # multi daemons mode:
    permissionToCollectTasks=""
    # remark: no need to try to acquire lock if there is no task waiting or if all my slots are busy
    if [ ! -z "$multiDaemons" ] && [ $nbWait -gt 0 ] && [ $myNbRun -lt $nbSlots ]; then
	if [ ! -f "$workDir/lock" ]; then
	    echo "Daemon $daemonId: creating lock with my ID" 1>&2
	    echo "$daemonId" > "$workDir/lock"
	    sleep $lockSleepTime
	    x=$(cat "$workDir/lock")
	    if [ "$x" ==  "$daemonId" ]; then # ok, job for current process
		echo "Daemon $daemonId: I got the job" 1>&2
		permissionToCollectTasks="yep"
	    else
		echo "Daemon $daemonId: didn't get the job" 1>&2
	    fi
	else
	    echo "Daemon $daemonId: work dir locked, coming back later" 1>&2
	fi
    else
	permissionToCollectTasks="yep"
    fi
    if [ ! -z "$permissionToCollectTasks" ]; then
#	echo "DEBUG nbWait=$nbWait; myNbRun=$myNbRun; nbSlots=$nbSlots" 1>&2
	while [ $nbWait -gt 0 ] && [ $myNbRun -lt $nbSlots ]; do # need to start a new task
	    nbIterIdle=0 # reset counter of idle iterations
	    nextBatch=$(mktemp)
            getTask "old" "wait" "$batchSize" >$nextBatch
            nbBatch=$(cat "$nextBatch" | wc -l)
#	    echo "DEBUG: '$nextBatch', size $nbBatch" 1>&2
            cat "$nextBatch" | while read f; do
		t=$(timeElapsedSinceFileWasModified "$f")
		while [ $t -lt $waitAtLeastTimeAfterFileWritten ]; do
                    sleep $waitAtLeastTimeAfterFileWritten
                    t=$(timeElapsedSinceFileWasModified "$f")
		done
		if [ $verbose -ge 2 ]; then
                    echo "INFO: Starting task '$f' (waiting time: ${t}s)"
		fi
		echo "$taskInitCommand"  > "$f.processing" # empty line if not used
		cat "$f" >> "$f.processing"
		# when process has been done, remove the first and the last line (which were added just here)
		echo "head -n -1 \"$f.running\" | tail -n +2 > \"$f.done\" ; rm -f \"$f.running\""  >>"$f.processing"
		rm -f "$f"
		if [ -z "$debugDir" ]; then
		    mv  "$f.processing" "$f.running"
		else
		    cat  "$f.processing" >"$f.running"
		    mv  "$f.processing" "$debugDir"
		fi
		# adding to the list of current tasks
		echo "$f" >>"$myCurrentTasksFile"
            done
	    if [ -z "$runScript" ]; then
		cat "$nextBatch" | while read taskFile; do
		    bash "$taskFile.running" &
		done
	    else
		eval "$runScript \"$nextBatch\""
	    fi
            rm -f "$nextBatch"
            myNbRun=$(( $myNbRun + $nbBatch ))
            nbWait=$(( $nbWait - $nbBatch )) # remark: we don't update status with actual files inside this inner loop
	done
	if [ ! -z "$multiDaemons" ]; then # the lock was obtained for this daemon, release it now
            echo "Daemon $daemonId: job done, removing lock" 1>&2
	    rm -f "$workDir/lock"
	fi
    fi
    if [ $(( $iterNo % summaryEveryNIterations )) -eq 0 ]; then
	nbs=$(getCurrentNbGlobal)
	printSummary $nbs
    fi

    sleep $sleepTime
    iterNo=$(( $iterNo + 1 ))
done

