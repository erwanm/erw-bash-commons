#!/bin/bash

# EM Nov 16

source common-lib.sh
source file-lib.sh

progName=$(basename "$BASH_SOURCE")


function usage {
  echo
  echo "Usage: $progName [options] <file>"
  echo
  echo "  Prints information about the specified file:"
  echo "   - output of the 'file' utility;"
  echo "   - if text file, basic statistics with the 'wc' utility."
  echo
  echo "  Options:"
  echo "    -h this help"
  echo
}




OPTIND=1
while getopts 'h' option ; do 
    case $option in
	"h" ) usage
 	      exit 0;;
	"?" ) 
	    echo "Error, unknow option." 1>&2
            printHelp=1;;
    esac
done
shift $(($OPTIND - 1))
if [ $# -ne 1 ]; then
    echo "Error: expecting 1 arg." 1>&2
    printHelp=1
fi
if [ ! -z "$printHelp" ]; then
    usage 1>&2
    exit 1
fi
file="$1"

tmp=$(mktemp --tmpdir)
file -b "$file" > "$tmp"
if grep "text" "$tmp"; then  # only if text file
    nBytes=$(cat "$file" | wc -c)
    nChars=$(cat "$file" | wc -m)
    nWords=$(cat "$file" | wc -w)
    nLines=$(cat "$file" | wc -l)
    echo -e "Size: $nBytes bytes;\t$nChars chars;\t$nWords words;\t$nLines lines"
fi
