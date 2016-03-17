#!/bin/bash


source common-lib.sh
source file-lib.sh

startDate=$(date +"%y.%m.%d %H:%M")
progName=$(basename "$BASH_SOURCE")
workDir=

maxSleepBetweenTasks=5
maxTaskDuration=20

function usage {
  echo
  echo "Usage: $progName [options] <work dir> <nb tasks>"
  echo
  echo "  generates dummy tasks which sleep a random amount of time"
  echo
  echo "  Options:"
  echo "    -h this help"
  echo "    -b <maxSleepBetweenTasks>"
  echo "    -d <maxTaskDuration>"
  echo
}






OPTIND=1
while getopts 'hb:d:' option ; do 
    case $option in
	"h" ) usage
 	      exit 0;;
	"b" ) maxSleepBetweenTasks="$OPTARG";;
	"d" ) maxTaskDuration="$OPTARG";;
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
nbTasks="$2"


mkdirSafe "$workDir" "$progName,$LINENO: "

while [ $nbTasks -gt 0 ]; do
    duration=$(( $RANDOM % $maxTaskDuration ))
    task=$(mktemp --tmpdir="$workDir" "task.XXXXXXXX")
    echo "sleep ${duration}s" >"$task"
    echo "$(date) : submitting task '$task' (duration = ${duration}s)"
    nbTasks=$(( $nbTasks - 1 ))
    t=$(( $RANDOM % maxSleepBetweenTasks ))
    sleep "${t}s"
done
