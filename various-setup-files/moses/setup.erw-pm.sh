#!/bin/bash
# EM Feb 14
#
# Requires erw-bash-commons to have been activated
# This script must be sourced from the directory where it is located
#

#addToEnvVar "$(pwd)/bin" PATH :
#for d in "$(pwd)/scripts"/*; do # all scripts added (not sure it's the best way to do it? alternative: a general $MOSES_PATH en var)
#    addToEnvVar "$d" PATH :
#done
# changed my mind because of quest: only setting MOSES_PATH
erw-pm activate srilm
erw-pm activate giza-pp
setEnvVar "$(pwd)" MOSES_PATH :
