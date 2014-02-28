#!/bin/bash

# Important: This script must be sourced (not only called) from the
# directory where it is located.

export ERW_BASH_UTILS_PATH="$(pwd)"
source $ERW_BASH_UTILS_PATH/common-lib.sh
addToEnvVar "$ERW_BASH_UTILS_PATH" PATH ":"
currentPath="$(pwd)"
cd "$ERW_BASH_UTILS_PATH/.."
addToEnvVar "$(pwd)" ERW_PM_REPO ":"
cd "$currentPath"
addToEnvVar erw-bash-utils ERW_PM_ACTIVE ":"
