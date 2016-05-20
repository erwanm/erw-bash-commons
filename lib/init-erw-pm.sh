#!/bin/bash

# EM April 14
#
# script which initializes the "project mgmt" system, allowing operations such as:
# erw-pm activate <project id>
# erw-pm addrepo <repository path>
#
# IMPORTANT: the call to this script must be "sourced".
#
#
source $(dirname "$BASH_SOURCE")/project-mgmt.sh

progName=$(basename "$BASH_SOURCE")
isSourced || echo "$progName: Warning: it seems that this script is called normally instead of being sourced" 1>&2

projectPath=$(dirname "$BASH_SOURCE")/.. # .. because this script is under subdir 'lib'
projectPath=$(absolutePath "$projectPath")
projectId=$(basename "$projectPath")

function usage {
    echo "Usage: source $progName"
    echo
    echo "  Remark: can be called from any location (supposedly!)"
}


# update april 14: no options currently, kept the "options parsing" block anyway but useless
OPTIND=1 # NECESSARY!!! otherwise any subsequent call will not find the argument, and stop the script with the corresponding error
         # (update: not true anymore since there is no arg anymore, but still correct this way of course)
printHelp=
while getopts 'h' option ; do 
    case $option in
	"h" ) usage
	    exitOrReturnError 0 ;;
	"?" ) 
	    echo "Error, unknow option." 1>&2
	    printHelp=1;;
    esac
done
shift $(($OPTIND - 1))
if [ $# -ne 0 ]; then
    echo "Error: expecting 0 args." 1>&2
    printHelp=1
fi
if [ ! -z "$printHelp" ]; then
    usage 1>&2
    exitOrReturnError 1
fi



pushd "$projectPath" >/dev/null
# next line not needed anymore: it is sufficient that the directory is in PATH, source will find the libs this way
#setEnvVar "$projectPath" "ERW_BASH_COMMONS_PATH" 
erw-pm addrepo ".."
erw-pm activate "$projectId" # adds the current dir to PATH
popd  >/dev/null

