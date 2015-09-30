#!/bin/bash
# Created by Roel Van de Paar, Percona LLC

if [ "" == "$1" ]; then
  echo "This script deletes a given trial (from a combinations.pl run) completely. Execute from the combinations.pl workdir"
  echo "Example: to delete trial 1000, execute as: ./delete_single_trial.sh 1000"
  exit 1
elif [ "`echo $1 | sed 's|[0-9]*||'`" != "" ]; then
  echo "Trial number should be a numeric value and isn't (value passed to this script: '$1')"
  exit 1
elif [ ! -r "trial$1.log" ]; then
  if [ ! -d "vardir1_$1" ]; then
    if [ ! -r "vardir1_$1.tar.gz" ]; then
      echo "This script deletes a given trial (from a combinations.pl run) completely. Execute from the combinations.pl workdir"
      echo "Error: trial number '$1' was passed as an option to this script. However, no trial $1 files exists! Please check and retry."
      exit 1
    fi
  fi
fi
TRIAL=$1

rm -f  trial$TRIAL.log        # Must succeed (it was present in check above), or report failure (i.e. no redirect to /dev/null)
rm -f  vardir1_$TRIAL.tar.gz  > /dev/null 2>&1
rm -Rf vardir1_$TRIAL         > /dev/null 2>&1
rm -f  cl$TRIAL cl_binmode$TRIAL cl_mtr$TRIAL cl_binmode_mtr$TRIAL > /dev/null 2>&1
rm -f  cmd$TRIAL cmdtrace$TRIAL start$TRIAL start_mtr$TRIAL init$TRIAL start_wipe_mtr$TRIAL > /dev/null 2>&1 
rm -f  $TRIAL.sql > /dev/null 2>&1
rm -Rf rundir1_$TRIAL         > /dev/null 2>&1
rm -f  cmd$TRIAL.log_* 
rm -f  cmd$TRIAL.log stop$TRIAL stop_mtr$TRIAL test$TRIAL test_mtr$TRIAL wipe$TRIAL $TRIAL.out > /dev/null 2>&1
rm -f  dump$TRIAL dump_mtr$TRIAL gdb_${TRIAL}_*.txt master_${TRIAL}_*.err > /dev/null 2>&1
rm -Rf BUNDLE_$TRIAL CORE_$TRIAL BUNDLE_$TRIAL.tar.gz 2>&1

if [ -r $TRIAL[a-zA-Z]*.sql* ]; then
  echo "- Trial #$TRIAL and all related files wiped. To optionally delete the SQL trace from this trial use: rm -f $TRIAL.[a-zA-Z]*.sql*"
else
  echo "- Trial #$TRIAL and all related files wiped"
fi
