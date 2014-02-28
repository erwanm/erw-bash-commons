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

source $ERW_BASH_UTILS_PATH/common-lib.sh
source $ERW_BASH_UTILS_PATH/file-lib.sh

defaultDepFileName="deps.erw-pm"
setupFileName="setup.erw-pm.sh"

#
# This is a library for several functions related to my "project
# management" system, more precisely dependency management. It is
# intended to be "sourced" from a script which needs to use one of
# these functions.
#
# Principle: the ERW_PM_REPO env. variable must be set from
# outside, typically in ~/.bashrc. It can contain several paths
# separated by ':'. Any time a project A depends on project B
# (indicated by the fact that the dependency file $defaultDepFilename
# in project A contains the name "B"), it should call ensureProjectDeps
# in its setup script.  The function will (1) check if the project is
# already active (belongs to the list contained in en var
# ERW_PM_ACTIVE); (2) if not, it will search the directories in
# ERW_PM_REPO, setup the project if found or return with an
# error if it can not find a subdirectory B.
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
# In order to use this PM system the project erw-bash-utils (which
# contains this library) must have been initialized (the setup script
# sourced from its own directory), and the ERW_PM_REPO should have
# been set (the setup script will automatically add the repo in which
# it is located, other repos have to be added manually)
#
#





#
# reads "projects" names from STDIN (one by line) and checks that
# there is a directory with each name in the ERW_PM_REPO env var.
# optionally if extra directories are provided as arguments they will
# also be checked (actually before) in the same way as the any dir in
# ERW_PM_REPO.
#
function ensureProjectDeps {
    currentDir=$(pwd)
    activeProjects=$(echo "$ERW_PM_ACTIVE" | sed "s/:/ /g")
    repos=$(echo "$ERW_PM_REPO" | sed "s/:/ /g")
    repos="$@$repos"
#    echo "ensureProjectDeps repos='$repos'" 1>&2
    while read projectName; do
#	echo "ensureProjectDeps: looking for '$projectName'" 1>&2
	memberList "$projectName" "$activeProjects" ":"
	if [ $? -ne 0 ]; then # if not already active
#	    echo "ensureProjectDeps: '$projectName' not active yet" 1>&2
	    projDir=$(searchEntryInDirList "$projectName" "$repos" ":")
	    if [ -z "$projDir" ]; then # not found in the repositories
		echo "Error, missing dependency: no directory '$projectName' found in the list of repositories '$repos'" 1>&2
		return 1 ### HALT ###
	    else
#		echo "ensureProjectDeps: found '$projectName' dir in '$projDir', activating it" 1>&2
		execInDir -s "$projDir/$setupFileName"
	    fi
	fi
    done
}


# global variable(s) initialization
#export ___ERW_BASH_UTILS_PROJECT_MGMT_LIB___=1

