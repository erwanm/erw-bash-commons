#!/bin/bash

#twdoc
#
# EM Feb 2014
#
# This a library of bash functions; to use any of these the calling
# script must "source" this library.
#
#/twdoc

source $(dirname "$BASH_SOURCE")/common-lib.sh

libName=$(basename "$BASH_SOURCE")
[ "$BASH_SOURCE" != "$0" ] || echo "$libName: Warning: it seems that this library is called normally instead of being sourced" 1>&2


#twdoc searchEntryInDirList $entry $dirsList [$separator]
#
# * $entry: searched entry
# * $dirsList: list of directories separatated by space (default)
# * $separator: optional, if the separator is different from space
#
# for every dir in the list, searches if dir/entry exists;
# prints the path of the first occurrence found to STDOUT
# or the empty string if not found.
#
# Remark: the entry can be either a dir or a file. The
# caller is responsible for checking this if needed.
#
#/twdoc
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


#twdoc linkAbsolutePath $destEntry $targetFile1 [... $targetFileN]
#
# * $destEntry is a file or directory where the symbolic link(s) will be created:
# ** if $destEntry is a directory, creates a symlink located in $destEntry pointing to $targetFileI for each file $targetFileI;
# ** if $destEntry is a file, creates a symlink $destEntry pointing to $targetFile1 (only one target file permitted).
#
#/twdoc
function linkAbsolutePath {
    local thisDir=$(pwd)
    local dest="$1"
    local targetDir=
    local dir=
    shift
    while [ ! -z "$1" ]; do # for every target file
	if [ -e "$1" ]; then
	    cd $(dirname "$1")
	    targetDir=$(pwd)
	    cd "$thisDir"
	    if [ -d "$dest" ]; then
		cd "$dest"
		if [ -e "$(basename "$1")" ]; then
		    echo "Warning: '$(basename "$1")' already exists in '$dest'" 1>&2
		else
		    ln -s "$targetDir/$(basename "$1")"
		fi
	    else
		dir=$(dirname "$dest")
		if [ -e "$dir" ]; then
		    cd "$dir"
		    if [ -e $(basename "$dest") ]; then
			echo "Warning: '$(basename "$dest")' already exists in '$dir'" 1>&2
		    else
			ln -s "$targetDir/$(basename "$1")" "$(basename "$dest")"
		    fi
		else
		    echo "Error: dest dir $dir does not exist" 1>&2
		    exitOrReturnError 1
		fi
	    fi
	    cd "$thisDir"
	else
	    echo "Error: target file $1 does not exist" 1>&2
	    exitOrReturnError 1
	fi
	shift
    done
}


#twdoc absolutePath $entry
#
# * $entry is either a file or a directory
#
# Prints the absolute path of $entry to STDOUT.
#
#/twdoc
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


#twdoc dieIfNoSuchDir $dir [$prefixMsg]
#
# Interrupts the program if the directory ``$dir`` does not exist.
#
#/twdoc
function dieIfNoSuchDir {
    local dir="$1"
    local prefixMsg="$2"
    if [ ! -d "$dir" ]; then
	echo "${prefixMsg}Error: directory '$dir' does not exist" 1>&2
	exitOrReturnError 1
    fi
}


#twdoc dieIfNoSuchFile $file [$prefixMsg]
#
# Interrupts the program if the file ``$file`` does not exist.
#
#/twdoc
function dieIfNoSuchFile {
    local file="$1"
    local prefixMsg="$2"
    if [ ! -f "$file" ]; then
	echo "${prefixMsg}Error: file '$file' does not exist" 1>&2
	exitOrReturnError 1
    fi
}



#twdoc mkdirSafe $dir [$prefixMsg]
#
# does nothing if the directory ``$dir`` already exists, otherwise tries to
# create it and stops with an error if the creation failed. Parent directories are created if needed.
#
#/twdoc
function mkdirSafe {
    local dir="$1"
    local prefixMsg="$2"
    if [ ! -d "$dir" ]; then
	mkdir -p "$dir"
	if [ $? -ne 0 ]; then
	    echo "${prefixMsg}Error: Cannot create '$dir'" 1>&2
	    exitOrReturnError 1
	fi
    fi
}


#twdoc mountSSH $mountFrom $mountTo [$prefixMsg] [$quiet]
#
# Mounts a remote path as an SSH filesystem. SSH keys should have been configured, otherwise the password will be asked.
# Prints a warning if ``$mountedFrom`` is already mounted to a different
#   directory, does nothing if already mounted to ``$mountTo``.
#
# * ``$mountFrom``: the mounted remote path: ``[user@]machine:path``
# * ``$mountTo``: the target directory where the remote path is mounted
# * ``$prefixMsg``: optional
# * ``$quiet``: if empty, prints an information message.
#
#/twdoc
function mountSSH {
    local mountFrom="$1"
    local mountTo="$2"
    local prefixMsg="$3"
    local quiet="$4"
    if [ -z "$quiet" ]; then
	echo "${prefixMsg}Info: mountSSH from '$mountFrom' to '$mountTo'"
    fi
    mkdirSafe "$mountTo" "$mountSSH: "
    mtabLine=$(grep "$mountFrom" /etc/mtab) # already mounted?
    alreadyMounted=
#    echo "debug 1 mtabLine='$mtabLine'"
    if [ ! -z "$mtabLine" ]; then
	mountPoint=$(echo "$mtabLine" | cut -f 2 -d " ")
#	echo "debug mountPoint='$mountPoint' ; mountTo='$mountTo'" 1>&2
	if [ "$mountPoint" != "$mountTo" ]; then
	    echo "${prefixMsg}Warning: $mountFrom already mounted to $mountPoint" 1>&2
	else
	    alreadyMounted=1
	fi
    fi
    if [ -z "$alreadyMounted" ]; then
	if [ $(ls -A "$mountTo" | wc -l) -gt 0 ]; then
	    echo "${prefixMsg}Error: directory $mountPoint is not empty." 1>&2
	    exitOrReturnError 1
	else
#	    echo "DEBUG: sshfs $mountFrom $mountTo" 1>&2
	    timeout 15s sshfs "$mountFrom" "$mountTo"
	    if [ $? -ne 0 ]; then
		echo "Warning: sshfs '$mountFrom' '$mountTo' returned non-zero exit code or timed out" 1>&2
	    fi
	fi
    fi
}


#twdoc cloneDir $sourceDir $destDir [$overwrite]
#
# Creates a copy of ``$sourceDir``, where every subdir is created under ``$destDir``
# and every file is symlinked to the source file. the dest dir (root) must have been created before.
#
#/twdoc
function cloneDir {
    local source="$1"
    local dest="$2"
    local overwrite="$3"

#    echo "DEBUG cloning $source to $dest"
    for entry in "$source"/*; do
        if [ -d "$entry" ]; then
            name=$(basename "$entry")
            mkdirSafe "$dest/$name" "$progName:$LINENO: "
            cloneDir "$entry" "$dest/$name"
        elif [ -f "$entry" ]; then
            entryName=$(basename "$entry")
            if [ ! -z "$overwrite" ] && [ -e "$dest/$entryName" ]; then
                rm -f "$dest/$entryName"
            fi
            if [ ! -e "$dest/$entryName" ]; then
                linkAbsolutePath "$dest" "$entry"
            fi
        else
            echo "$progName: Warning cloneDir: $entry is neither a directory or a regular file, ignored" 1>&2
        fi
    done
}

