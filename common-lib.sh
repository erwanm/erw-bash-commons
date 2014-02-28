#!/bin/bash
# EM Feb 2014
#
# The setup script for erw-bash-utils must have been called before
# using this library.
#
# This a library of bash functions; to use any of these the calling
# script must "source" this library.
#
#




# args: 
# STDIN = 
# $1 = <searched item>
# $2 = <list of items separatated by space (default)>
# $3 = [separator] if the separator is different from space
#
# returns 0 if true, 1 otherwise.
#
function memberList {
    item="$1"
    list="$2"
    sep="$3"
    if [ ! -z "$sep" ]; then
	list=$(echo "$list" | sed "s/$sep/ /g")
    fi
#    echo "memberList: searching '$item' in '$list'" 1>&2
    set -- $list
    while [ ! -z "$1" ]; do
#	echo "memberList: '$item' == '$1' ?" 1>&2
	if [ "$item" == "$1" ]; then
#	echo "memberList: '$item' found, returning 0" 1>&2
	    return 0
	fi
	shift
    done
#    echo "memberList: end of list, returning 1" 1>&2
    return 1
}


#
# prints the current script location 
#
# Warning: does not work if the script has been sourced instead of
# called normally. Also if called inside a function which has been
# read from a library, it will return the location of the calling
# script, not the library file.
#
#
function getScriptLocation {
    # one-liner:
    # DIR="$( cd "$( dirname "$0" )" && pwd )"
    cd "$( dirname "$0" )"
    pwd
}



#
# assigns $1 to $2, where $2 is the name of an env. var.
# (not sure it's worth a function though)
#
function setEnvVar {
    export $2="$1"
}



#
# adds an element to a list in an environment variable only if it does
# not belong to it yet (default separator is space).
#
# args: 
# $1: <item> to add to the list 
# $2: <target> the name of the env var
# $3: [separator] specify the separator if not space
#
function addToEnvVar {
    newItem=$1
    varName=$2
    sepa=${3:- }
#    echo "addToEnvVar: adding $newItem to $varName" 1>&2
    content=$(eval "echo \$$varName")
    if [ -z "$content" ]; then
#	echo "addToEnvVar: $varName was empty" 1>&2
	export $varName="$newItem"
    else
#	echo "addToEnvVar: searching $newItem in '$content'" 1>&2
	memberList "$newItem" "$content" ":"
	if [ $? -ne 0 ]; then # not in the list yet
#	    echo "addToEnvVar: $newItem not found, adding it" 1>&2
	    export $varName="$content$sepa$newItem"
	fi
    fi
#    echo "addToEnvVar: new value $varName=$(eval "echo \$$varName")" 1>&2
}


#
# executes a script/program in its directory.
# args: [-s] <executable file (with full path)>
# if option -s is provided, the script is sourced instead of only executed.
#
function execInDir {
    sourceIt=
    if [ "$1" == "-s" ]; then
	sourceIt=1
	shift
    fi
    path=$(dirname "$1")
    executable=$(basename "$1")
    pushd "$path" >/dev/null
    if [ -z "$sourceIt" ]; then
#	echo "execInDir: executing $executable from $(pwd)" 1>&2
	./"$executable"
    else
#	echo "execInDir: sourcing $executable from $(pwd)" 1>&2
	source "$executable"
    fi
    popd >/dev/null
}



# global variable(s) initialization

#export ___ERW_BASH_UTILS_COMMON_LIB___=1

