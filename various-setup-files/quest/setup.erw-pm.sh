#!/bin/bash
# EM Feb 14
#
# Requires erw-bash-commons to have been activated
# This script must be sourced from the directory where it is located
#

erw-pm activate srilm
erw-pm activate moses
erw-pm activate TreeTagger
addToEnvVar "$(pwd)/build/classes" CLASSPATH :
for f in "$(pwd)"/lib/*.jar; do
    addToEnvVar "$f" CLASSPATH :
done
