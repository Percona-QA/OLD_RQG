#!/bin/bash
# Updated by Roel Van de Paar, Percona LLC

## This script will delete known errors from the RQG run directory
## If you want to delete any specific error from the RQG run directory, pass one parameter with error info (in double quotes)
## Example: ./cleanup_known.sh "InnoDB. log block checksum mismatch. expected"
## OTOH, to clean all "known issue/bug" trials as listed in ./known_bugs.strings, simply execute the script, without options, from within the RQG run directory

# Internal variables
SCRIPT_PWD=$(cd `dirname $0` && pwd)  # Needed to find other scripts required, as well as known_bugs.strings
TRIALS=( $(ls trial*.log 2>/dev/null) )

delete_trials_error_log(){
  grep -l "${STRING}" vardir[0-9]_*/log/master.err | sed 's/vardir[0-9]//;s/[^0-9]//g' | xargs -I_ $SCRIPT_PWD/delete_single_trial.sh _
}

delete_trials_trial_log(){
  grep -l "${STRING}" trial*.log | sed 's/[^0-9]//g' | xargs -I_ $SCRIPT_PWD/delete_single_trial.sh _
}

if [ "" == "$1" ]; then
  # Delete all known issues by scanning the error log AND trial log for known issue strings
  while read line; do
    STRING="`echo $line | sed 's|[ \t]*##.*$||'`"
    if [ "`echo "$STRING" | sed 's|^[ \t]*$||' | grep -v '^[ \t]*#'`" != "" ]; then
      delete_trials_error_log
      delete_trials_trial_log
    fi
  sync; sleep 0.02  # Making sure that next line in file does not trigger same deletions
  done < ${SCRIPT_PWD}/known_bugs.strings
else
  # This will delete trials with specific error strings by scanning the error log AND trial log for said string
  STRING=$1
  delete_trials_error_log
  delete_trials_trial_log
fi

