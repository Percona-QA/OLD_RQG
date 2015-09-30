#!/bin/bash
# Created by Roel Van de Paar, Percona LLC

if [ "" == "$1" ]; then
  echo "This script keeps a given trial (from a combinations.pl run) completely (i.e. all files included) in the KEEP directory"
  echo "within a given combinations.pl workdir. Execute this script directly from within the combinations.pl workdir."
  echo "Example: to keep trial 1000, execute as: ./keep_single_trial.sh 1000"
  exit 1
elif [ ! -r "trial$1.log" ]; then
  echo "This script keeps a given trial (from a combinations.pl run) completely (i.e. all files included) in the KEEP directory"
  echo "within a given combinations.pl workdir. Execute this script directly from within the combinations.pl workdir."
  echo "Error: trial number '$1' was passed as an option to this script. However, no trial$1.log exists! Please check and retry."
  exit 1
else
  TRIAL=$1
fi

# Attempt making KEEP directory (or; it may already exist)
mkdir KEEP > /dev/null 2>&1
if [ ! -d KEEP ]; then
  echo "Error: there is no KEEP subdirectory here, even after we attempted creating one"
  exit 1
fi

mv trial$TRIAL.log KEEP    # Must succeed (it was present in check above), or report failure (i.e. no redirect to /dev/null)
mv vardir1_$TRIAL.tar.gz KEEP > /dev/null 2>&1
mv vardir1_$TRIAL KEEP > /dev/null 2>&1
mv cl$TRIAL cl_binmode$TRIAL cl_mtr$TRIAL cl_binmode_mtr$TRIAL KEEP > /dev/null 2>&1
mv cmd$TRIAL cmdtrace$TRIAL start$TRIAL start_mtr$TRIAL init$TRIAL start_wipe_mtr$TRIAL KEEP > /dev/null 2>&1
mv $TRIAL.sql KEEP > /dev/null 2>&1
mv rundir1_$TRIAL KEEP > /dev/null 2>&1
mv run$TRIAL.log_* $TRIAL[a-zA-Z]*.sql* KEEP > /dev/null 2>&1
mv run$TRIAL.log stop$TRIAL stop_mtr$TRIAL test$TRIAL test_mtr$TRIAL wipe$TRIAL $TRIAL.out KEEP > /dev/null 2>&1
mv dump$TRIAL dump_mtr$TRIAL gdb_${TRIAL}_*.txt master_${TRIAL}_*.err KEEP > /dev/null 2>&1
mv BUNDLE_${TRIAL}.tar.gz KEEP > /dev/null 2>&1
rm -Rf CORE_${TRIAL} BUNDLE_${TRIAL} > /dev/null 2>&1

echo "- Trial #$TRIAL and all related files moved to ./KEEP"
