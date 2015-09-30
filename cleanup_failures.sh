#!/bin/bash
# Created by Roel Van de Paar, Percona LLC

# The first option is the workdir
if [ "" == "$2" ]; then
  echo "Use with caution. Removes all established known issues for a given combinations.pl run based on a search string"
  echo "No valid parameters were passed. Need a status (1) and a search string to cleanup on (2). Retry."
  echo "Example use: \$cleanup_failures.sh SERVER_CRASHED 'srv_log_block_size'"
  echo "Note; if you want to delete all items for a given status, use 'a' (or shortly: a) as the search string"
  echo "Note; this script relies on the STATUS ./{status passed as first option} scripts to be present"
  echo "Note; this script relies on the delete_single_trial.sh script to be present in the same directory as this script"
  exit 1
else
  STATUS=$1
  CLEANUP_STRING=$2
fi

SCRIPT_PWD=$(cd `dirname $0` && pwd)

./$1.sh 2>&1 | grep "$CLEANUP_STRING" | grep -v "fatal:" | \
  sed 's/===> [cdvi] //;s/vardir1_//;s/\/.*//g;s/; vi.*//g;s/\[tail_master.err\]//g;s/\[tail_bootstrapl\]//g;s/trial\([0-9]*\)\.log.*/\1/' | sort -u | \
  xargs -Inr $SCRIPT_PWD/delete_single_trial.sh nr
