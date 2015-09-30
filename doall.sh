#!/bin/bash
# Created by Roel Van de Paar, Percona LLC

DEBUG=0  # When set to 1, user will be required to press enter between each step doall.sh executes 

# startup.sh will be handled by the script as well, so remove it here.
if [ "" == "$1" ]; then
  echo "This script executes startup.sh man, then cmdtrace, and finally prepare_reducer.sh."
  echo "It expects one parameter: the trial number to analyze"
  exit 1
else
  TRIAL=$1
fi

SCRIPT_PWD=$(cd `dirname $0` && pwd)
WORKD_PWD=$PWD

echo "======================================================================================= Running startup.sh ${TRIAL} man"
$(echo -e "\n\n") | ${SCRIPT_PWD}/startup.sh ${TRIAL} man
if [ $DEBUG -eq 1 ]; then read -p "Press enter to continue..."; fi

echo "======================================================================================= Running cmdtrace${TRIAL}"
${WORKD_PWD}/cmdtrace${TRIAL}
if [ $DEBUG -eq 1 ]; then read -p "Press enter to continue..."; fi

echo "======================================================================================= Running prepare_reducer.sh ${TRIAL}"
${SCRIPT_PWD}/prepare_reducer.sh ${TRIAL}
if [ $DEBUG -eq 1 ]; then read -p "Press enter to continue..."; fi

echo "======================================================================================= Veryfing status outcomes"
if [ ! -r trial${TRIAL}.log ]; then
  ORIG_STATUS="Could not locate trial${TRIAL}.log, so the original trial's run status could not be determined"
else 
  ORIG_STATUS=`tail -n1 trial${TRIAL}.log | sed 's|.*STATUS|STATUS|;s| .*||'`
  if [ "`echo $ORIG_STATUS | sed 's|STATUS.*|STATUS|'`" != "STATUS" ]; then
    ORIG_STATUS=`grep "STATUS_" trial${TRIAL}.log | tail -n1 | sed 's|.*STATUS|STATUS|;s| .*||'`
    if [ "`echo $ORIG_STATUS | sed 's|STATUS.*|STATUS|'`" != "STATUS" ]; then
      ORIG_STATUS="Could not be determinted, please check trial${TRIAL}.log for the original trial's run actual status"
    fi
  fi
fi
if [ ! -r cmd${TRIAL}.log ]; then
  CMD_STATUS="Could not locate cmd${TRIAL}.log, so the cmdtrace trial's run status could not be determined"
else 
  CMD_STATUS=`tail -n1 cmd${TRIAL}.log | sed 's|.*STATUS|STATUS|;s| .*||'`
  if [ "`echo $CMD_STATUS | sed 's|STATUS.*|STATUS|'`" != "STATUS" ]; then
    CMD_STATUS=`grep "STATUS_" cmd${TRIAL}.log | tail -n1 | sed 's|.*STATUS|STATUS|;s| .*||'`
    if [ "`echo $CMD_STATUS | sed 's|STATUS.*|STATUS|'`" != "STATUS" ]; then
      CMD_STATUS="Could not be determinted, please check trial${TRIAL}.log for the cmdtrace trial's run actual status"
    fi
  fi
fi

if [ -r ./vardir1_${TRIAL}/log/master.err ]; then
  ORIG_SIG=`grep "got signal" ./vardir1_${TRIAL}/log/master.err | sed 's|.*mysqld got ||;s| ;||'`
  ORIG_TEXT=`egrep -i 'Assertion failure.*in file.*line' vardir1_${TRIAL}/log/master.err | sed 's|.*in file ||;s| |DUMMY|g';echo $(egrep 'Assertion.*failed' vardir1_${TRIAL}/log/master.err | sed 's|\&\&|..|g;s/||/../g;s|"|.|g;s|^.*Assertion .||;s|. failed.*$||;s| |DUMMY|g';egrep 'mysqld\(_' vardir1_${TRIAL}/log/master.err;egrep 'mysqld\(' vardir1_${TRIAL}/log/master.err | egrep -v 'mysqld\(_') | tr ' ' '\n' | sed 's|.*mysqld[\(_]*||;s|).*||;s|+.*$||;s|DUMMY| |g;s|($||' | head -n1`
fi
if [ -r ./rundir1_${TRIAL}/log/master.err ]; then
  CMD_SIG=`grep "got signal" ./rundir1_${TRIAL}/log/master.err | sed 's|.*mysqld got ||;s| ;||'`
  CMD_TEXT=`egrep -i 'Assertion failure.*in file.*line' rundir1_${TRIAL}/log/master.err | sed 's|.*in file ||;s| |DUMMY|g';echo $(egrep 'Assertion.*failed' rundir1_${TRIAL}/log/master.err | sed 's|\&\&|..|g;s/||/../g;s|"|.|g;s|^.*Assertion .||;s|. failed.*$||;s| |DUMMY|g';egrep 'mysqld\(_' rundir1_${TRIAL}/log/master.err;egrep 'mysqld\(' rundir1_${TRIAL}/log/master.err | egrep -v 'mysqld\(_') | tr ' ' '\n' | sed 's|.*mysqld[\(_]*||;s|).*||;s|+.*$||;s|DUMMY| |g;s|($||' | head -n1`
fi

echo "Original trial run status: $ORIG_STATUS ($ORIG_SIG: $ORIG_TEXT)"
echo "Cmdtrace trial run status: $CMD_STATUS ($CMD_SIG: $CMD_TEXT)"
if [ "$ORIG_STATUS" == "$CMD_STATUS" -a "$ORIG_SIG" == "$CMD_SIG" -a "$ORIG_TEXT" == "$CMD_TEXT" ]; then 
  echo "These statuses match exactly, which indicates you should be good to for running reducer${TRIAL}.sh"
  echo -e "\nDone! You can now modify reducer${TRIAL}.sh variables (Recommended: set MODE=3 instead of MODE=4 in machine variable settings section and modify TEXT string), and subsequently you can start reducer by executing: ./reducer${TRIAL}.sh ${TRIAL}b.sql"
else
  echo -e "These statuses do not seem to match (though note that status grepping from logs may not be 100% perfect), which indicates you should check that the cmdtrace${TRIAL} trial run had the same end result as the original trial run. Verify this by comparing end STATUS and end result (i.e. assertion/crash etc.) in trial${TRIAL}.log vs cmd${TRIAL}.log. You can also check error log contents in ./vardir1_${TRIAL}/log/master.err (original trial) vs ./rundir1_${TRIAL}/log/master.err (cmdtracei${TRIAL} trial).\n\nNote that if they do not match, there is usually (though not always - think 'sporadic') little point in running reducer (reducer${TRIAL}.sh). The best course of action is usually to re-execute cmdtrace${TRIAL} - but with a doubled --duration=x setting (edit the file before starting). Sometimes, and especially when a server is loaded with other jobs, it takes longer to re-produce an issue given that now the SQL is being traced to disk. Also, if the issue is sporadic, it may need to hit a certain condition a few times before all elemenents to trigger a particular issue are correct. So, even a few tries of cmdtrace${TRIAL} are definitely not out of place."
  echo -e "\nIf you want to change the duration and re-run (once or a few times in case once does not reproduce the issue) cmdtrace${TRIAL} (recommended), then execute ./cmdtrace${TRIAL} and subsequently verify/compare the end result/end STATUS in trial${TRIAL}.log vs cmd${TRIAL}.log (it is best if they match). Alternatively (not recommended), you can now modify reducer${TRIAL}.sh variables, and subsequently start reducer by executing: ./reducer${TRIAL}.sh ${TRIAL}b.sql"
fi
