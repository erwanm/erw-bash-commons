#!/bin/bash
# EM Feb 2014
#
# The setup script for erw-bash-commons must have been called before
# using this library.
#
# This a library of bash functions; to use any of these the calling
# script must "source" this library.
#
#

source $ERW_BASH_COMMONS_PATH/common-lib.sh

# args: 
# STDIN = 
# $1 = <searched entry>
# $2 = <list of directories separatated by space (default)>
# $3 = [separator] if the separator is different from space
#
# for every dir in the list, searches if dir/entry exists;
# prints the path of the first occurrence found to STDOUT
# or the empty string if not found.
#
# Remark: the entry can be either a dir or a file. The
# caller is responsible for checking this if needed.
#
function searchEntryInDirList {
    entry="$1"
    dirs="$2"
    sep="$3"
    if [ ! -z "$sep" ]; then
	dirs=$(echo "$dirs" | sed "s/$sep/ /g")
    fi
    set -- $dirs
    while [ ! -z "$1" ]; do
	if [ -e "$1/$entry" ]; then
	    echo "$1/$entry"
	    return 0
	fi
	shift
    done
    echo ""
    return 0
}



#
# $1 = dest dir/file, $2..$n = target files
# if $1 is a dir, for each $X, X>1, creates a symlink located in $1 pointing to $X
# if $1 is a file only one target is permitted: creates a symlink $1 pointing to $2
#
function linkAbsolutePath {
    thisDir=$(pwd)
    dest="$1"
    shift
    while [ ! -z "$1" ]; do # for every target file
	if [ -e "$1" ]; then
	    cd $(dirname "$1")
	    targetDir=$(pwd)
	    cd "$thisDir"
	    if [ -d "$dest" ]; then
		cd "$dest"
		ln -s $targetDir/$(basename "$1")
	    else
		dir=$(dirname "$dest")
		if [ -e "$dir" ]; then
		    cd "$dir"
		    ln -s $targetDir/$(basename "$1") $(basename "$dest")
		else
		    echo "Error: dest dir $dir does not exist" 1>&2
		    exit 1
		fi
	    fi
	    cd "$thisDir"
	else
	    echo "Error: target file $1 does not exist" 1>&2
	    exit 1
	fi
	shift
    done
}


function absolutePath {
    local entry="$1"
    if [ -d "$entry" ]; then
	pushd "$entry" >/dev/null
	pwd
	popd >/dev/null
    else
	pushd $(dirname "$entry") >/dev/null
	dir=$(pwd)
	echo "$dir/$(basename "$entry")"
	popd >/dev/null
    fi
}



function dieIfNoSuchDir {
    local dir="$1"
    local prefixMsg="$2"
    if [ ! -d "$dir" ]; then
	echo "${prefixMsg}Error: directory '$dir' does not exist" 1>&2
	exit 1
    fi
}


function dieIfNoSuchFile {
    local file="$1"
    local prefixMsg="$2"
    if [ ! -f "$file" ]; then
	echo "${prefixMsg}Error: file '$file' does not exist" 1>&2
	exit 1
    fi
}



#
# does nothing if the dir already exists, tries to
# create it and stops with an error if it didn't work.
#
function mkdirSafe {
    local dir="$1"
    local prefixMsg="$2"
    if [ ! -d "$dir" ]; then
	mkdir "$dir"
	if [ $? -ne 0 ]; then
	    echo "${prefixMsg}Error: Can not create '$dir'" 1>&2
	    exit 1
	fi
    fi
}
