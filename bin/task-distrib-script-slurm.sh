#!/bin/bash

# EM March 16

source common-lib.sh
source file-lib.sh

startDate=$(date +"%y.%m.%d %H:%M")
progName=$(basename "$BASH_SOURCE")

function usage {
  echo
  echo "Usage: $progName [options] <config dir> <tchpc project> <tchpc partition> <tchpc time by task> <tasks list file>"
  echo
  echo "  auxiliary script for task-distrib-daemon.sh to be used with a slurm cluster."
  echo
  echo "  Options:"
  echo "    -h this help"
  echo
}




function fullPathFile {
    local f="$1"
    pushd $(dirname "$f") >/dev/null
    d=$(pwd)
    echo "$d/$(basename "$f")"
    popd >/dev/null
}




OPTIND=1
while getopts 'h' option ; do 
    case $option in
	"h" ) usage
 	      exit 0;;
	"?" ) 
	    echo "Error, unknow option." 1>&2
            printHelp=1;;
    esac
done
shift $(($OPTIND - 1))
if [ $# -ne 5 ]; then
    echo "Error: expecting 5 args." 1>&2
    printHelp=1
fi
if [ ! -z "$printHelp" ]; then
    usage 1>&2
    exit 1
fi
taskConfigsDir="$1"
project="$2"
partition="$3"
tchpcTime="$4"
listFile="$5"


id=$(date +"%y.%m.%d-%H.%M.%S")
f=$(mktemp --tmpdir="$taskConfigsDir" "$id.XXXXXXXX")
script="$f.sh"
config="$f.conf"
rm -f "$f" # unusre

config=$(fullPathFile "$config")
echo "#!/bin/bash" >"$script"
echo "#SBATCH -n 8" >>"$script"
echo "#SBATCH -t $tchpcTime" >>"$script"
echo "#SBATCH -p $partition" >>"$script"
echo "#SBATCH -U $project" >>"$script"
echo "#SBATCH -J $(basename "$script")" >>"$script"
echo "srun --multi-prog $config" >>"$script"

no=0
cat "$listFile" | while read f; do
    f2=$(fullPathFile "$f")
    echo "$no bash $f2.running" >>"$config"
    no=$(( $no + 1 ))
done
no=$(cat "$config" | wc -l)
while [ $no -lt 8 ]; do
    echo "$no sleep 3s" >>"$config"
    no=$(( $no + 1 ))
done
sbatch "$script" >/dev/null
