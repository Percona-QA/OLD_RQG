#!/bin/bash
# Created by Roel Van de Paar, Percona LLC

# Deletes ALARM status RQG trials for which there are no errors of any importance in the server log
# It does so by checking for which trials ALARM.sh does not return any important failures
# (Wheter this is the case or not is determined by the $FINDS and $IGNOR variables in rqg_results.sh)

SCRIPT_PWD=$(cd `dirname $0` && pwd)

./ALARM.sh 2>&1 | tr -d '\n' | sed 's|vardir\([_0-9]*\)/log/master.err <======>|\nDO:\1\n|g' | \
  grep "^DO:" | sed 's/^DO:1_//' | grep -v "No such" | xargs -Inr $SCRIPT_PWD/delete_single_trial.sh nr
