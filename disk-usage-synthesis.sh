#!/bin/bash

# EM May 14
#
progName=$(basename "$BASH_SOURCE")

source "common-lib.sh"

sizeMin=3%
depthMax=2
unit=G
optOnlyFileThisSystem=" -x "
percentageOccupied=
localSize=
indentLevel=
sudoDu=

function usage {
    echo "Usage: $progName [root directory]"
    echo
    echo "  Utility which prints the biggest sub-directories recursively according to"
    echo "  the parameters provided. By default only prints the directories with a size"
    echo "  higher than $sizeMin, at a depth lower than $depthMax."
    echo "  If no argument is provided, processes the current dir."
    echo
    echo "Options:"
    echo "  -h print this help mesage and exit"
    echo "  -u <K|M|G|T> unit in kilo-, mega-, giga- or terabyes; default: $unit."
    echo "  -d <max depth> max levels of subdirs for a dir to be printed. default: $depthMax"
    echo "  -s <size min[%]> min size for a subdir to be printed; can be an absolute "
    echo "     size or a percentage (of the total partition space, see also -o). If an"
    echo "     absolute size, must be expressed in the current unit (see -u)."
    echo "      default value: $sizeMin."
    echo "     remark: the value (percentage or not) must be an integer."
    echo "  -o percentage of occupied space instead of total partition space."
    echo "  -r percentage of space in root dir instead of total partition space."
    echo "     TODO"
    echo "  -x by default the search does not to take into account dirs on"
    echo "     different filesystems; -x reverts that. (remark: opposite meaning"
    echo "     to the 'du' command!)"
    echo "  -l local size; for each directory, do not take its subdirectors into "
    echo "     account in its size, except if it is at the level max depth (i.e"
    echo "     its subdirectories won't be printed). This option gives a more"
    echo "     synhetic view of where the big files actually are located, and"
    echo "     as the interesting effect of making the percentage sizes consistent"
    echo "     with each other (that is, the sum cannot be higher than 100%)"
    echo "     TODO not great, maybe abort (not well specified, e.g. case of 1 subdir>t but not other others?)"
    echo "  -S call 'du' with sudo"
    echo
    echo "     Warning: won't work if the directory spans over several partitions."
    echo
    echo " TODO: pretty print/opt no space before?, opt indent level"
}


function convertToUnit {
    local value="$1"
    case $unit in
	"K" ) echo "$value";;
	"M" )  perl -e "printf('%.1f',$value /1024); ";;
	"G" )  perl -e "printf('%.1f',$value /1024**2); ";;
	"T" )  perl -e "printf('%.1f',$value /1024**3); ";;
	* ) echo "Error: invalid unit '$unit'" 1>&2
	    exit 3;;
    esac
    
}



OPTIND=1
printHelp=
while getopts 'hld:s:u:oxS' option ; do 
    case $option in
	"h" ) usage
	    exitOrReturnError 0 ;;
	"u" ) unit=$OPTARG;;
	"S" ) sudoDu=1;;
	"d" ) depthMax=$OPTARG;;
	"s" ) sizeMin=$OPTARG;;
	"o" ) percentageOccupied=1;;
	"x" ) optOnlyFileThisSystem="";;
	"l" ) localSize=1;;
	"?" ) 
	    echo "Error, unknow option." 1>&2
	    printHelp=1;;
    esac
done
shift $(($OPTIND - 1))
if [ $# -gt 1 ]; then
    echo "Error: expecting 0 or 1 args." 1>&2
    printHelp=1
fi
if [ ! -z "$printHelp" ]; then
    usage 1>&2
    exitOrReturnError 1
fi
rootDir=${1:-.}



dfOutput=$(df -T "$rootDir" | tail -n 1)
set -- $dfOutput
if [ -z "$percentageOccupied" ]; then
    totalSpace="$3" # total partition space
else
    totalSpace="$4" # total used space
fi


accuSubDirs=( 0 ) # will contain the total size of all subdirs for each currently studied levels
lastAncestorLevel=0
# no use of -B because it rounds up the value to the unit (e.g. 3k becomes 1G)
command="du --max-depth $depthMax $optOnlyFileThisSystem $rootDir"
if [ ! -z "$sudoDu" ]; then
    command="sudo $command"
fi
eval "$command" | while read duLine; do
    printIt=
    set -- $duLine
    size="$1"
    shift
    dir="$@"
    if [ ! -z "$localSize" ]; then
	dirLevelS=$(echo "$dir" | sed 's:[^/]::g')
	dirLevel=${#dirLevelS}
	parentLevel=$(( $dirLevel - 1 ))
#	echo "DEBUG dir=$dir; dirLevel=$dirLevel; parentLevel=$parentLevel; sizeInUnit=$sizeInUnit; lastAncestorLevel=$lastAncestorLevel; array=${accuSubDirs[@]}" 1>&2
	if [ $dirLevel -gt $lastAncestorLevel ]; then # new branch: either first case, or sibling at lastAncestorLevel (possibly deep); in any case it must be a leaf,
	    # i.e. either a dir with no subdirs or a dir at max depth; in both cases it local size = its total size.
	    # we only have to add its size to the total for subdirs of its parent dir
	    for i in $(seq $(( $lastAncestorLevel + 1 )) $parentLevel); do
		accuSubDirs[$i]=0 # new slots
	    done
	    lastAncestorLevel=$parentLevel
	    accuSubDirs[$parentLevel]=$(perl -e "print  $size + ${accuSubDirs[$parentLevel]};")
	else # rolling back to parent dir (dirLevel can only be lastAncestorLevel +1, i.e. lastAncestorLevel = parentLevel)
	        # we need to update the local size (substract subdirs size) and close the branch in the array
	    if [ $dirLevel -gt 0 ]; then # not root: update parent level
		accuSubDirs[$parentLevel]=$(perl -e "print ${accuSubDirs[$parentLevel]} + $size;")
		lastAncestorLevel=$parentLevel
	    fi
	    size=$(perl -e "print  $size - ${accuSubDirs[$dirLevel]};" ) # substract size of subdirs from the total size for the current dir
#	    echo "after (2): lastAncestorLevel=$lastAncestorLevel; array=${accuSubDirs[@]}" 1>&2
	fi
    fi
    asPercentage=$( perl -e " printf('%4.1f\%', $size * 100 / $totalSpace); ")
    sizeInUnit=$(convertToUnit $size)
    if [[ $sizeMin == *% ]]; then
	intPart=${asPercentage%.*}
	if [ $intPart -ge ${sizeMin%\%} ] ; then
	    printIt=1
	fi
    else
	intPart=${sizeInUnit%.*}
	if [ $intPart  -ge $sizeMin ]; then
	    printIt=1
	fi
    fi
    if [ ! -z "$printIt" ]; then
	echo -e "$dir\t$sizeInUnit\t$asPercentage"
    fi
done | tac | while read line; do
    dir=$(echo "$line" | cut -f 1)
    size=$(echo "$line" | cut -f 2)
    sizeP=$(echo "$line" | cut -f 3)
    owner=$(stat -c "%U" "$dir")
    if [ ! -z "$indentLevel" ]; then
	dirLevelS=$(echo "$dir" | sed 's:[^/]::g')
	dirLevel=${#dirLevelS}
	echo -n "$dirLevelS" | sed 's:/:   :g'
	echo -ne "$(basename "$dir")"
	echo -e "\t$owner\t$size\t$sizeP"
    else
	echo -e "$size\t$sizeP\t$owner\t$dir"
    fi
    lastDir="$dir"
done


