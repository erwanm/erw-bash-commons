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
# TODO: update explanations!
#
# Principle: the ERW_PM_REPO env. variable must be set from outside,
# typically in ~/.bashrc [update: in init-erw-pm.sh ].  It can contain
# several paths separated by ':'. Any time a project A depends on
# project B (indicated by the fact that the dependency file
# $defaultDepFilename in project A contains the name "B"), it should
# call ensureProjectDeps in its setup script.  The function will (1)
# check if the project is already active (belongs to the list
# contained in en var ERW_PM_ACTIVE); (2) if not, it will search the
# directories in ERW_PM_REPO, setup the project if found or return
# with an error if it can not find a subdirectory B.
#
# The setup script must:
#
# - source this library (from the directory where it is located);
#
# - call ensureProjectDeps (recommended even if the project does not
#   depend on any other, but not needed);
#
# - update the ERW_PM_ACTIVE env var in the following way: 
#   addToEnvVar $projectName ERW_PM_ACTIVE :
#
# Any call to a setup script must be done with "source" and from the
# directory where the setup script is located.
#
# In order to use this PM system the project erw-bash-commons (which
# contains this library) must have been initialized (the setup script
# sourced from its own directory), and the ERW_PM_REPO should have
# been set (the setup script will automatically add the repo in which
# it is located, other repos have to be added manually)
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
#	    echo "activateProjectIfNeeded: '$projectName' not active yet" 1>&2
	local projDir=$(searchEntryInDirList "$projectName" "$repos" ":")
	if [ -z "$projDir" ]; then # not found in the repositories
	    echo "Error, missing dependency: no directory '$projectName' found in the list of repositories '$repos'" 1>&2
	    exitOrReturnError 1 ### HALT ###
	else
#		echo "activateProjectIfNeeded: found '$projectName' dir in '$projDir', activating it" 1>&2
	    activateProjectDir "$projDir"
	fi
    fi
}


function activateProjectDir {
    echo "DEBUG activateProjectIfNeeded: $@" 1>&2
    local dir=$(absolutePath "$1")
    projectId=$(basename "$dir")
    export TRUC=machin2
    addToEnvVar "$projectId" ERW_PM_ACTIVE :
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
        * )
            echo "$commandId: error, invalid command '$command'" 1>&2
            commandUsage 1>&2
	    exitOrReturnError $invoked
    esac
}



function commandAddRepo {
#    echo "DEBUG addRepo $@" 1>&2
    if [ -z "$1" ]; then
	echo "$commandId addrepo: error, missing argument" 1>&2
	commandUsage 1>&2
	exitOrReturnError $invoked
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
    if [ -z "$1" ]; then
	echo "$commandId activate: error, missing argument" 1>&2
	commandUsage 1>&2
	exitOrReturnError $invoked
    fi
    while [ ! -z "$1" ]; do
	activateProjectIfNeeded "$1"
	shift
    done
}



# TODO option only active/only non active?
#
function commandList {
#    echo "DEBUG options=$@" 1>&2
    local printActive=1
    local printInactive=1
    local printStatus=1
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
	exitOrReturnError $invoked
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

