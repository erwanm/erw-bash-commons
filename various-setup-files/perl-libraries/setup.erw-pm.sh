#!/bin/bash
# EM Feb 14
#
# Requires erw-bash-commons to have been activated
# This script must be sourced from the directory where it is located
#

#ensureProjectDeps <deps.erw-pm
#for d in lib/perl/* share/perl/*; do 
#    if [ -d "$d" ]; then
#	addToEnvVar $(pwd)/$d PERL5LIB :
#    fi
#done
addToEnvVar $(pwd)/lib/perl5 PERL5LIB :
addToEnvVar "$(pwd)/bin" PATH :
