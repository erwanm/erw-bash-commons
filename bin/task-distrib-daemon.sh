#!/bin/bash

# EM April 15, modified March 16

source common-lib.sh
source file-lib.sh

startDate=$(date +"%y.%m.%d %H:%M")
progName=$(basename "$BASH_SOURCE")
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
debugMode=0


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
  echo "    -f force deletion of previously existing <task>.running files"
  echo "    -c continue normally with previously existing <task>.running files"
  echo "       (-f is ignored)"
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
  echo "    -d debug mode: keep the '.processing' version of the task as '.bak'."
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
function getCurrentNb {
    # info: using a file because 'ls dir/*.done'  will sometimes give an error "argument list too long"
    # see also http://www.linuxjournal.com/article/6060?page=0,0
    tmp=$(mktemp) 
    ls "$workDir" >"$tmp" 2>/dev/null
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
    evalSafe "$comm  | head -n $nb |  sed 's:^:$workDir/:g'" "$progName,$LINENO: "
}


function printSummary {
    nbWait=$1
    nbRun=$2
    nbDone=$3
    
    now=$(date +"%y.%m.%d %H:%M")
    echo "SUMMARY $now: $nbWait tasks waiting, $nbRun tasks running, $nbDone tasks done since $startDate."
    if [ $nbRun -gt 0 ]; then
	f=$(getTask "old" "run")
	s=$(timeElapsedSinceFileWasModified "$f" 1)
	echo -n "          Oldest task running, started $s ago: "
	basename "${f%.running}"
	f=$(getTask "new" "run")
	s=$(timeElapsedSinceFileWasModified "$f" 1)
	echo -n "          Newest task running started $s ago: "
	basename "${f%.running}"
	if [ $verbose -ge 1 ]; then
	    echo "        Recently achieved tasks:"
	    getTask "new" "done" "$printNbLastDone" | while read f; do
		s=$(timeElapsedSinceFileWasModified "$f" 1)
		echo "          $(basename ${f%.done}) (done $s ago)"
	    done
	    echo "        Currently running tasks:"
	    getTask "new" "run" "$nbSlots" | while read f; do
		s=$(timeElapsedSinceFileWasModified "$f" 1)
		echo "          $(basename ${f%.running}) (started ${s} ago)"
	    done
	    
	fi
    else
	echo "        no task running currently."
    fi
}






OPTIND=1
while getopts 'vVhs:p:fcb:e:i:d' option ; do 
    case $option in
	"d" ) debugMode=1;;
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


mkdirSafe "$workDir" "$progName,$LINENO: "

nbs=$(getCurrentNb)
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

iterNo=0
while [ 1 == 1 ]; do
    nbs=$(getCurrentNb)
    nbRun=$(echo "$nbs" | cut -f 2)
    nbWait=$(echo "$nbs" | cut -f 1)

    while [ $nbWait -gt 0 ] && [ $nbRun -lt $nbSlots ]; do # need to start a new task
	nextBatch=$(mktemp)
        getTask "old" "wait" "$batchSize" >$nextBatch
#	echo "DEBUG: '$nextBatch'" 1>&2
#	exit 4
        nbBatch=$(cat "$nextBatch" | wc -l)
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
            echo "head -n 2 \"$f.running\" > \"$f.done\" ; rm -f \"$f.running\""  >>"$f.processing"
            rm -f "$f"
	    if [ $debugMode -ne 1 ]; then
		mv  "$f.processing" "$f.running"
	    else
		cat  "$f.processing" >"$f.running"
		mv  "$f.processing" "$f.bak"
	    fi
        done
	if [ -z "$runScript" ]; then
	    cat "$nextBatch" | while read taskFile; do
		bash "$taskFile.running" &
	    done
	else
	    eval "$runScript \"$nextBatch\""
	fi
        rm -f "$nextBatch"
        nbRun=$(( $nbRun + $nbBatch ))
        nbWait=$(( $nbWait - $nbBatch )) # remark: we don't update status with actual files inside this inner loop
    done
    if [ $(( $iterNo % summaryEveryNIterations )) -eq 0 ]; then
	nbs=$(getCurrentNb)
	printSummary $nbs
    fi

    sleep $sleepTime
    iterNo=$(( $iterNo + 1 ))
done

