#!/bin/bash
# Created by Roel Van de Paar, Percona LLC

# This script analyzes an individual trial which has crashed

if [ "" == "$1" ]; then
  echo "This script analyzes an individual trial which has crashed. It expects one parameter: the trial number to analyze"
  exit 1
else
  TRIAL=$1
  if [ ! -r ./trial${TRIAL}.log ]; then
    echo "Something is wrong: ./trial${TRIAL}.log does not exist or cannot be read?"
    exit 1
  else
    if [ ! -d ./vardir1_${TRIAL} ]; then
      echo "Something is wrong: ./vardir1_${TRIAL} does not exist?"
      exit 1
    fi
  fi
fi

WORKD_PWD=$PWD
BASE=`grep -m1 'basedir=' trial$1.log | sed 's|^.*basedir=/|/|;s| .*$||'`
echo "BASE directory: ${BASE}"

cd vardir1_${TRIAL}/master-data
CORE=`ls -1 *core* 2>&1 | head -n1 | grep -v "No such file"`

if [ "" == "${CORE}" ]; then
  echo "Something is wrong: there is no (script readable) [vg]core in ./vardir1_${TRIAL}/master-data/ ?"
  exit 1
fi

if [ -r ${BASE}/bin/mysqld ]; then
  BIN=${BASE}/bin/mysqld
else
  # Check if this is a debug build by checking if debug string is present in dirname
  if [[ ${BASE} = *debug* ]]; then
    if [ -r ${BASE}/bin/mysqld-debug ]; then
      BIN=${BASE}/bin/mysqld-debug
    else
      echo "Something is wrong: there is no (script readable) mysqld binary at ${BASE}/bin/mysqld[-debug] ?"
      exit 1
    fi
  else
    echo "Something is wrong: there is no (script readable) mysqld binary at ${BASE}/bin/mysqld ?"
    exit 1
  fi
fi

TIMEF=`date +%d%m%y-%H%M`

# For debugging purposes, remove ">/dev/null 2>&1" on the next line and observe output
gdb ${BIN} ${CORE} >/dev/null 2>&1 <<EOF
  # Avoids libary loading issues / more manual work, see bash$ info "(gdb)Auto-loading safe path"
  set auto-load safe-path /         
  # See http://sourceware.org/gdb/onlinedocs/gdb/Threads.html - this avoids the following issue:
  # "warning: unable to find libthread_db matching inferior's threadlibrary, thread debugging will not be available"
  set libthread-db-search-path /usr/lib/
  set trace-commands on
  set pagination off
  set print pretty on
  set print array on
  set print array-indexes on
  set print elements 4096
  set logging file gdb_${TRIAL}_${TIMEF}_FULL.txt
  set logging on
  thread apply all bt full
  set logging off
  set logging file gdb_${TRIAL}_${TIMEF}_STD.txt
  set logging on
  thread apply all bt
  set logging off
  quit
EOF

# Cleanup old files for this trial
rm $WORKD_PWD/gdb_${TRIAL}_*.txt 2>/dev/null
rm $WORKD_PWD/master_${TRIAL}_*.err 2>/dev/null

# Copy gdb logs, then error log if present. Then report
cp gdb_${TRIAL}_${TIMEF}_*.txt $WORKD_PWD
echo "Full GDB trace saved in $WORKD_PWD/gdb_${TRIAL}_${TIMEF}_FULL.txt (all threads bt + local variables)"
echo "Standard GDB trace saved in $WORKD_PWD/gdb_${TRIAL}_${TIMEF}_STD.txt (all threads bt)"

if [ -r ../log/master.err ]; then
  cp ../log/master.err ./master_${TRIAL}_${TIMEF}.err
  cp ./master_${TRIAL}_${TIMEF}.err $WORKD_PWD
  echo "mysqld error log saved in $WORKD_PWD/master_${TRIAL}_${TIMEF}.err"
  echo -e "\n3 Files generated: $WORKD_PWD/gdb_${TRIAL}_${TIMEF}_STD.txt $WORKD_PWD/gdb_${TRIAL}_${TIMEF}_FULL.txt $WORKD_PWD/master_${TRIAL}_${TIMEF}.err"
else
  echo "Something is wrong: there is no (script readable) error log at ./vardir1_${TRIAL}/log/master.err"
  echo "Nonetheless, a core file was found and a backtrace analysis was saved (ref above)"
  echo -e "\n2 Files generated: $WORKD_PWD/gdb_${TRIAL}_${TIMEF}_STD.txt $WORKD_PWD/gdb_${TRIAL}_${TIMEF}_FULL.txt"
fi

