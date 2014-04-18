#!/bin/bash
# EM Feb 2014
#
# This a library of bash functions; to use any of these the calling
# script must "source" this library.
#
#

libName=$(basename "$BASH_SOURCE")
[ "$BASH_SOURCE" != "$0" ] || echo "$libName: Warning: it seems that this library is called normally instead of being sourced" 1>&2


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



#
# assigns a variable with the name "$name" (same as un the parameter file), so that
# it does not need to be called as myvar=$(readFromParamFile ...), because in this
# case the function would not be able to make the calling script die.
#
function readFromParamFile {
    local file="$1"
    local name="$2"
    local errMsgPrefix="$3"
    local sepa="$4"
    if [ -z "$sepa" ]; then
	sepa="="
    fi
    dieIfNoSuchFile "$file"
    res=$(grep "^$name$sepa" "$file" | cut -d "$sepa" -f 2- | tail -n 1)
    if [ -z "$res" ]; then
	echo "${errMsgPrefix}Error: parameter '$name' not found in parameter file '$file'" 1>&2
	exitOrReturnErrorCode 14
    fi
    eval "$name=\"$res\""
}


#
# runs the command provided with eval and die if the return status is not zero
#
function evalSafe {
    local command="$1"
    local errMsgPrefix="$2"
    eval "$command"
    code=$?
    if [ $code -ne 0 ]; then
	echo "${errMsgPrefix}Error: command '$command' returned with error code $code" 1>&2
	exitOrReturnError 1
    fi
}


#
# returns 0 only if the current script is sourced from the very first
# level, i.e. when variables modifications in the first-level script
# apply globally and a call to "exit" in the first-level script would
# end the bash session (1 otherwise).  
#
# Remark: if a sub-script is called without "source" somewhere in the
# stack of calls, this function still considers that it is sourced
# even though it actually operates in a sub-shell.
#
#
# OBSOLETE (version 1) returns 0 only if the current script is
# sourced at any level, i.e. if "source" appears at any level in the
# function call stack.  Remark: the fact that a library has been
# sourced and one of its function is used anywhere does not mean that
# it is sourced, since the function is usually executed in a
# non-sourced context and not in the library where it was defined.
#
#
function isSourced {
    local lastFunc=${#FUNCNAME[@]}
    lastFunc=$(( $lastFunc - 1 )) # the array seems to be indexed from 0 to N-1
# VERSION 1: return true if "source" is at any level
#    local foundSource=1
#    for i in $(seq 1 $lastFunc); do
#	echo "DEBUG isSourced: BASH_SOURCE[$i]=${BASH_SOURCE[$i]} ; FUNCNAME[$i]=${FUNCNAME[$i]}" 1>&2
#	if [ "${FUNCNAME[$i]}" == "source" ]; then
#	    foundSource=0
#	fi
#   done
#    return $foundSource
# VERSION 2: return true only if "source" is in the last element of the stack, i.e. the very first call was sourced
    if [ "${FUNCNAME[$lastFunc]}" == "source" ]; then
	return 0
	else
	return 1
    fi
}


#
# stops the execution either by "return" or "exit" depending on whether the script is being sourced or not.
#
function exitOrReturnError {
    local errCode=${1:-1}
#    if [ "${BASH_SOURCE[0]}" == "$0" ] ; then # wrong inside a function called from outside (${BASH_SOURCE[0]} is this lib name, not the calling script)
    if isSourced; then
#	echo "DEBUG: return: ${FUNCNAME[1]}" 1>&2
       return $errCode
    else
#	echo "DEBUG: exit: ${FUNCNAME[1]}" 1>&2
        exit $errCode
#	return $errCode
    fi
}


# global variable(s) initialization


