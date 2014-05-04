#!/bin/bash
# EM Feb 2014; update April 14
#
#
#
libName=$(basename "$BASH_SOURCE")
[ "$BASH_SOURCE" != "$0" ] || echo "$libName: Warning: it seems that this library is called normally instead of being sourced" 1>&2

source $(dirname "$BASH_SOURCE")/common-lib.sh
source $(dirname "$BASH_SOURCE")/file-lib.sh

commandId="erw-pm"
setupFileName="setup.erw-pm.sh"

#
# This is a library for several functions related to my "project
# management" system, more precisely dependency management. It is
# intended to be "sourced" from a script which needs to use one of
# these functions.
#
#
# Principle: the "system" must be initialized by a sourced call to
# init-erw-pm.sh, typically in ~/.bashrc:
#
# source path/to/erw-bash-commons/init-erw-pm.sh
#
# This will source all the needed libraries (including the present
# one). Then the functions needed become available at all time,
# especially "erw-pm", which is the main one (call erw-pm help to see
# the options).  The directory which contains erw-bash-commons is
# automatically added to the list of repositories stored in the env
# var ERW_PM_REPO; other repositories must be added manually,
# e.g. with
#
# erw-pm addrepo path/to/repo
#
# Every project P must contain a file $setupFileName which makes any
# needed initializations, in particular activating any required
# dependency (i.e. others project which need to be active for the
# project P to work), setting the path in PATH, etc. Example:
#
# erw-pm activate Text-TextAnalytics
# erw-pm activate TreeTagger
# erw-pm activate erw-R-commons
# erw-pm activate perl-libraries
# addToEnvVar "$(pwd)/bin" PATH :
#
# 
#




#
# activateProjectIfNeeded <project> [<extra repo1> [ <extra repo2> ...] ]
#
# if <project> is not already active, checks that there is a directory
# named <project> in at least one of the directories in ERW_PM_REPO
# env var and then activates it.

#  Optionally if extra directories are provided as arguments they will
# also be checked (actually before) in the same way as any dir in
# ERW_PM_REPO.
#
#
function activateProjectIfNeeded {
    local projectName="$1"
    shift
    local currentDir=$PWD
    local activeProjects=$(echo "$ERW_PM_ACTIVE" | sed "s/:/ /g")
    local repos=$(echo "$ERW_PM_REPO" | sed "s/:/ /g")
    repos="$@$repos"
#    echo "activateProjectIfNeeded repos='$repos'" 1>&2
#    echo "activateProjectIfNeeded: looking for '$projectName'" 1>&2
    memberList "$projectName" "$activeProjects"
    if [ $? -ne 0 ]; then # if not already active
#	echo "activateProjectIfNeeded: '$projectName' not active yet" 1>&2
	local projDir=$(searchEntryInDirList "$projectName" "$repos" ":")
	if [ -z "$projDir" ]; then # not found in the repositories
	    echo "Error, missing project/dependency: no directory '$projectName' found in the list of repositories '$repos'" 1>&2
	    exitOrReturnError 1 ### HALT ###
	else
#	    echo "activateProjectIfNeeded: found '$projectName' dir in '$projDir', activating it" 1>&2
	    activateProjectDir "$projDir"
	fi
    fi
}


function activateProjectDir {
#    echo "DEBUG activateProjectDir: $@" 1>&2
    local dir=$(absolutePath "$1")
    projectId=$(basename "$dir")
    export TRUC=machin2
    addToEnvVar "$projectId" ERW_PM_ACTIVE :
#    echo "DEBUG activateProjectDir: execting $dir/$setupFileName" 1>&2
    execInDir -s "$dir/$setupFileName"
}


# TODO
function commandUsage {
    echo "Usage: $commandId <command> [options]"
    echo
    echo "  Available commands:"
    echo "    addrepo"
    echo "    activate"
    echo "    list [-ai]"
    echo
}


function erw-pm {
#    echo "DEBUG erw-pm: $@" 1>&2
    command="$1"
    shift 1
    case "$command" in
        "addrepo" )
            commandAddRepo "$@";;
        "activate" )  
	    commandActivate "$@";;
        "list" )
	    commandList "$@";;
        "help" )
            commandUsage;;
        * )
            echo "$commandId: error, invalid command '$command'" 1>&2
            commandUsage 1>&2
	    exitOrReturnError 1
    esac
}



function commandAddRepo {
#    echo "DEBUG addRepo $@" 1>&2
    if [ -z "$1" ]; then
	echo "$commandId addrepo: error, missing argument" 1>&2
	commandUsage 1>&2
	exitOrReturnError 1
    fi
    while [ ! -z "$1" ]; do
        local dir=$(absolutePath "$1")
#	echo "DEBUG addRepo dir=$dir" 1>&2
        addToEnvVar "$dir" "ERW_PM_REPO" ":"
        shift
    done
}


# TODO add option to prepend new repos
#
function commandActivate {
#    echo "DEBUG: activate '$@'" 1>&2
    if [ -z "$1" ]; then
	currentDir=$(basename "$PWD")
	echo "$commandId activate: Warning: no argument provided, trying to activate current directory '$currentDir'" 1>&2
	activateProjectIfNeeded "$currentDir"
    else
	while [ ! -z "$1" ]; do
	    activateProjectIfNeeded "$1"
	    shift
	done
    fi
}



# TODO option only active/only non active?
#
function commandList {
#    echo "DEBUG options=$@" 1>&2
    local printActive=1
    local printInactive=1
    local printStatus=1
    local printHelp=
    OPTIND=1
    while getopts 'ia' option ; do 
	case $option in
	    "i" ) printActive=0
		  printStatus=0;;
	    "a" ) printInactive=0
		  printStatus=0;;
	    "?" ) 
		echo "$commandId list: error, unknow option." 1>&2
		printHelp=1;;
	esac
    done
    shift $(($OPTIND - 1))
    if [ $# -ne 0 ]; then
	echo "$commandId list: warning: unused argument(s)" 1>&2
	printHelp=1
    fi
    if [ ! -z "$printHelp" ]; then
	commandUsage 1>&2
	exitOrReturnError 1
    fi

    local repos=$(echo "$ERW_PM_REPO" | sed "s/:/ /g")
    local activeProjects=$(echo "$ERW_PM_ACTIVE" | sed "s/:/ /g")
    set -- $repos
    while [ ! -z "$1" ]; do
	for projectDir in "$1"/*; do
	    if [ -d "$projectDir" ] && [ -f "$projectDir/$setupFileName" ]; then
		local projectName=$(basename "$projectDir")
		memberList "$projectName" "$activeProjects" ":"
		local isInactive=$?
#		echo "DEBUG: printActive=$printActive; printInactive=$printInactive; printStatus=$printStatus; isInactive=$isInactive" 1>&2
		if [ $isInactive -eq 0 ] && [ $printActive -eq 1 ]; then
		    echo -n "$projectName"
		    if [ $printStatus -ne 0 ]; then
			echo -e "\tACTIVE"
		    else
			echo
		    fi
		elif [ $isInactive -ne 0 ] && [ $printInactive -eq 1 ]; then
		    echo -n "$projectName"
		    if [ $printStatus -ne 0 ]; then
			echo -e "\tINACTIVE"
		    else
			echo
		    fi
		fi
	    fi
	done
        shift
    done

}



# global variable(s) initialization (if any)

