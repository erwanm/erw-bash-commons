#!/bin/bash

# EM March 16
# update May 18 (-r option)

source common-lib.sh
source file-lib.sh

startDate=$(date +"%y.%m.%d %H:%M")
progName=$(basename "$BASH_SOURCE")
nbCores=8
runDirectly=""

function usage {
  echo
  echo "Usage: $progName [options] <config dir> <tchpc project> <tchpc partition> <tchpc time by task> <tasks list file>"
  echo
  echo "  auxiliary script for task-distrib-daemon.sh to be used with a slurm cluster."
  echo
  echo "  Options:"
  echo "    -h this help"
  echo "    -n <nb cores>, default: $nbCores."
  echo "    -r run parallel tasks directly with '&' rather using 'srun --multi-prog' with a config file."
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
while getopts 'hn:r' option ; do 
    case $option in
	"n" ) nbCores="$OPTARG";;
	"r" ) runDirectly="yep";;
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
rm -f "$f" # unusre
script="$f.sh"

echo "#!/bin/bash" >"$script"
echo "#SBATCH -t $tchpcTime" >>"$script"
echo "#SBATCH -p $partition" >>"$script"
echo "#SBATCH -U $project" >>"$script"
echo "#SBATCH -J $(basename "$script")" >>"$script"

if [ -z "$runDirectly" ]; then
    echo "#SBATCH -n $nbCores" >>"$script"
    echo "srun --multi-prog $config" >>"$script"
    config="$f.conf"
    config=$(fullPathFile "$config")
fi

no=0
cat "$listFile" | while read f; do
    f2=$(fullPathFile "$f")
    if [ -z "$runDirectly" ]; then
	echo "$no bash $f2.running" >>"$config"
    else
	echo "bash $f2.running &" >>"$script"
    fi
    no=$(( $no + 1 ))
done

if [ -z "$runDirectly" ]; then
    no=$(cat "$config" | wc -l)
    while [ $no -lt $nbCores ]; do
	echo "$no sleep 3s" >>"$config"
	no=$(( $no + 1 ))
    done
else
    echo "wait"  >>"$script"
fi
sbatch "$script" >/dev/null
