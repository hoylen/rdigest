#!/bin/sh
#
# Recursive digest calculator
#
# Requires: openssl
#
# Runs "openssl dgst -sha1" on all the files specified on the command
# line. For directories specified on the command line, it is applied
# to all normal files underneath it.
#
# Produces a similar result to this simple command:
#   openssl dgst -sha1 `find DIRECTORY -type f`
#
# But this script will also work when there are many files involved.
# This simple command will fail when there are a large number of
# files, because the length of the command line is limited.
#
# Copyright (C) 2013, Hoylen Sue.
#----------------------------------------------------------------

# Argument processing

PROGNAME=`basename $0`

HELP=
OUTFILE=
VERBOSE=

# Use GNU enhanced getopt if available, otherwise use getopt

getopt -T > /dev/null
if [ $? -eq 4 ]; then
    # GNU enhanced getopt is available
    # set -- `getopt --long help,output:,version --options ho:v -- "$@"`
    # TODO: the above uses the GNU enhanced getopt, but it puts single
    # quotes around file/directory arguments, which causes other things to fail
    set -- `getopt ho:v "$@"`
else
    # Use original getopt
    set -- `getopt ho:v "$@"`
fi

while [ $# -gt 0 ]; do
    case "$1" in
        -h | --help)     HELP=yes;;
        -o | --output)   OUTFILE="$2"; shift;;
        -v | --verbose)  VERBOSE=yes;;
        --)              shift; break;;
    esac
    shift
done

if [ "$HELP" = 'yes' ]; then
  echo "Usage: $0 [options] {directoryOrFile}"
  echo " -o | --output filename    output file for digests (default stdout)"
  echo " -h | --help               show this help information"
  #echo " -v | --verbose"
  exit 2
fi

if [ $# -lt 1 ]; then
  echo "Usage error: no files or directories specified (use -h for help)" >&2
  exit 2
fi

# Check all arguments exist. Better to fail fast, rather than find out
# later after wasting time calculating some of the digests.

ERROR=
for ARG in "$@"; do
  if [ ! -e "$ARG" ]; then
    echo "Error: directory or file does not exist: $ARG" >&2
    ERROR=yes
  else
    if [ ! -r "$ARG" ]; then
      echo "Error: file or directory is not readable: $ARG" >&2
      ERROR=yes
    fi
  fi
done
if [ -n "$ERROR" ]; then
  exit 1
fi

# Calculate digests on all arguments

if [ -n "$OUTFILE" ]; then
  # Create new file, or truncate an existing file, to zero bytes long
  :>"$OUTFILE"
else
  OUTFILE=/dev/stdout
fi

for ARG in "$@"; do
  find "$ARG" -type f  -exec openssl dgst -sha1 {} \; >>"$OUTFILE"
  if [ $? -ne 0 ]; then
     echo "Error: $PROGNAME aborted" >&2
     exit 1
  fi
done

exit 0

#EOF
