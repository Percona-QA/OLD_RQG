#!/bin/bash
# Created by Roel Van de Paar, Percona LLC

# This script handles various trial outcomes for a given RQG run (run from the RQG combinations.pl workdir containing all trialx.log files)
# Note; this script relies on the delete_single_trial.sh script to be present in the same directory as this script

# If you start rqg_results.sh with WIPE as the first option ($./rqg_results.sh WIPE) it will wipe all STATUS_ENVIRONMENT_FAILURE,
# all STATUS_INTERNAL_ERROR, and all STATUS_PERL_FAILURE failed trials by default

# Improvement ideas
# - If the last line of a trial does not specify STATUS_something then the generated run script(s) fail. This tend to happens when there is
#   an overflow of queries being written to the log by RQG while the trial has already ended. The failure is that the status is not
#   seen correctly and so not handled correctly. This really needs improving in function generate_out() by using a grep or something instead
# - "the age of the last checkpoint is": this is likely not an issue, maybe this one can be done in a way that rqg_results.sh already deletes them.
#   The script apparently already filters these sort of issues in it's output format (the error is not shown) so why not just delete them, *but*
#   have to ensure this is the *only* issue. If so, delete is likely fine, if confirmed first it is indeed benign. Same idea for "Lock wait timeout
#   exceeded; try restarting transaction" and "Sort aborted: Lock wait timeout exceeded; try restarting" - again, if they are the only issue seen.
# - Script need to be a bit smarter when it comes to "ERROR SUMMARY" in the error log. For example, DATABASE_CORRUPTION.sh shows Valgrind output 
#   "ERROR SUMMARY" [even if it is 0]. Have to make behaviour decision here.

TIMEF="/tmp/PQA_$(date +%s%N | cut -b8-19)"
SCRIPT_PWD=$(cd `dirname $0` && pwd)

LOGS=$(ls trial*.log 2>/dev/null)
if [ -z "$LOGS" ]; then
  echo "No RQG trial log files (*.log) found - are you sure you started this script from the RQG run work directory and that logs are present?"
  exit 1
elif [ "`c++filt 'a'`" != "a" ]; then
  echo "This script expects the c++filt demangler to be installed. Please install the GNU Binutils ($ sudo yum install binutils)"
  exit 1
fi

INPUT=$1

# Strings to look for or ignore when checking STATUS_ALARM trials
# Note that these are differently written then the Perl regexes in randgen/lib/GenTest/Reporter/ErrorLogAlarm.pm
FINDS="^Error:|ERROR|allocated at line|missing DBUG_RETURN|^safe_mutex:|Invalid.*old.*table or database|InnoDB: Warning|InnoDB: Error:|InnoDB: Operating system error|Error while setting value"
IGNOR="Lock wait timeout exceeded|Deadlock found when trying to get lock|innodb_log_block_size has been changed|Sort aborted:|ERROR: the age of the last checkpoint is [0-9]*,|consider increasing server sort buffer size|.ERROR. Event Scheduler:.*does[ ]*n.t exist"

# Main SED line used for parsing file rendered above. It starts by reporting on what file is being reported upon, 
# the other output is relevant per-STATUS only, and will be added per-STATUS below
MAINSED="s/.*TRIAL__\([0-9]*\)/echo '======================================================================================= vi trial\1.log | vi vardir1_\1\/log\/master.err'\n"

function generate_out(){
  tail -n1 *.log | \
    egrep "STATUS_|Lost connection to MySQL server|trial[0-9]" | \
    tr '\n' ' ' | \
    sed "s|)|)`echo '\n\r'`|g;s|<==||g;s|==>||g" | \
    sed "s|^.*trial\(.*\).log.*STATUS_\(.*\)|STATUS_\2\tTRIAL__\1|" | \
    sed "s|^.*trial\(.*\).log.*DBI connect.*|STATUS_ODD\tTRIAL__\1|" | \
    sort | \
    egrep -v "STATUS_OK" > $TIMEF

  cat $TIMEF | \
    sed "s|TRIAL__\([0-9]*\)|if [ ! -d vardir1_\1 ]; then tar -xf vardir1_\1.tar.gz; fi;\tvi trial\1.log;  \tvi vardir1_\1/log/master.err|g" > ./out.txt
}

function parse(){
  rm ./${STATUS}.sh >/dev/null 2>&1
  rm ./${STATUS}_FULL.sh >/dev/null 2>&1
  rm ./${STATUS}_untar.sh >/dev/null 2>&1
  rm ./${STATUS}_wipe.sh >/dev/null 2>&1
  COUNT=$(cat $TIMEF | grep "^STATUS_${STATUS}" | wc -l)
  if [ $COUNT -gt 0 ]; then
    echo "echo 'Note: this script will not untar existing directories again.'" > ./${STATUS}_untar.sh
    touch ./${STATUS}.sh
    echo "echo 'Count: $COUNT'" >> ./${STATUS}_untar.sh
    grep "^STATUS_${STATUS}" $TIMEF | sed "s/.*TRIAL__\([0-9]*\)/if [ ! -d vardir1_\1 ]; then tar -xf vardir1_\1.tar.gz; echo 'vardir1_\1.tar.gz extracted'; else echo 'vardir1_\1.tar.gz was already extracted'; fi /g" >> ./${STATUS}_untar.sh
    grep "^STATUS_${STATUS}" $TIMEF | sed "s|.*TRIAL__\([0-9]*\)|${SCRIPT_PWD}/delete_single_trial.sh \1|g" > ./${STATUS}_wipe.sh
    chmod +x ./${STATUS}_untar.sh ./${STATUS}.sh ./${STATUS}_wipe.sh
    [ "$INPUT" != "WIPE" ] && echo "Created ./${STATUS}_untar.sh to enable status STATUS_${STATUS} trials to be extracted (only needed once)"
    [ "$INPUT" != "WIPE" ] && echo "Created ./${STATUS}_wipe.sh to enable wiping all trials with exit status STATUS_${STATUS} at once"
    [ "$INPUT" != "WIPE" ] && echo "Created ./${STATUS}.sh to enable checking status STATUS_${STATUS} trials after extraction"
  else
    [ "$INPUT" != "WIPE" ] && echo "Skipped creating files for status STATUS_${STATUS} as there were no failed trials for this status"
  fi
}

# Pre-processig of trials to be dropped
# Generate out.txt, this time used just to see which trials are to be dropped
generate_out
grep "STATUS_ENVIRONMENT_FAILURE" $TIMEF | sed "s|.*TRIAL__\([0-9]*\)|trial\1.log|" | \
  xargs -I_ grep -lm1 "ERROR: Unknown error from transformer, likely a test issue. Raising status to STATUS_ENVIRONMENT_FAILURE" _ | \
  sed "s|trial||;s|.log||" | \
  xargs -Inr sh -c '${SCRIPT_PWD}/delete_single_trial.sh nr ; \
                    echo "Deleted trial #nr as it was a STATUS_ENVIRONMENT_FAILURE run due to a transformer issue (unimportant)"'

# Re-create out.txt, this time cleaner (i.e. without the trials dropped above)
generate_out
[ "$INPUT" != "WIPE" ] && echo "Created ./out.txt which contains the status outcome for ALL non-deleted trials (you may want to review this)"

# Actual trial processing
STATUS="ALARM"; parse
if [ $COUNT -gt 0 ]; then
  grep "^STATUS_${STATUS}" $TIMEF | sed "$(echo $MAINSED) \
    egrep -H '$(echo $FINDS)' vardir1_\1\/log\/master.err | egrep -v '$(echo $IGNOR)'/g" >> ./${STATUS}.sh
fi

STATUS="SERVER_CRASHED"; parse
if [ $COUNT -gt 0 ]; then
  grep "^STATUS_${STATUS}" $TIMEF | sed "$(echo $MAINSED) \
    echo -e \"\$(egrep -i 'got signal|sig=|Assert|ERROR.*InnoDB:' vardir1_\1\/log\/master.err | grep -v '-assert-')\\\n\$(echo \$(egrep 'mysqld\\\(_' vardir1_\1\/log\/master.err;egrep 'mysqld\\\(' vardir1_\1\/log\/master.err | egrep -v 'mysqld\\\(_';egrep 'mysqld\\\[' vardir1_\1\/log\/master.err) | tr ' ' '\n' | grep -v '==[0-9]*==' | grep -m5 '.' )\" | sed 's|.*\/bin\/mysqld||;s|.*mysqld got sig|mysqld got sig|;s|.*InnoDB: Assertion fail|InnoDB: Assertion fail|' | egrep -v '^$' | c++filt /g" >> ./${STATUS}.sh
fi

STATUS="DATABASE_CORRUPTION"; parse
#Old awk command to show last x lines of error log; Not much point to it. 
#Instead checking trial log for storage engine issues + checking error log for real errors ($FINDS) now
#awk '{contents[NR]=\$0} END {for (i=NR-100;i<=NR;i++){print FILENAME\":\"contents[i]}}' vardir1_\1\/log\/master.err | egrep -v '$(echo $IGNOR)|\\\[Note\\\]'
if [ $COUNT -gt 0 ]; then
  grep "^STATUS_${STATUS}" $TIMEF | sed "$(echo $MAINSED) \
    grep -H 'storage engine' trial\1.log;egrep -H '$(echo $FINDS)' vardir1_\1\/log\/master.err | egrep -v '$(echo $IGNOR)'/g" >> ./${STATUS}.sh
fi

STATUS="ENVIRONMENT_FAILURE"; parse
#Old ways inside main grep. Now replaced with "intelligent string search ($FINDS/$IGNOR)" commands
#awk '{contents[NR]=\$0} END {for (i=NR-10;i<=NR;i++){print \"[tail_master.err]\"FILENAME\":\"contents[i]}}' vardir1_\1\/log\/master.err\n \
#awk '{contents[NR]=\$0} END {for (i=NR-10;i<=NR;i++){print \"[tail_bootstrapl]\"FILENAME\":\"contents[i]}}' vardir1_\1\/log\/bootstrap.log/g" >> ./${STATUS}.sh
if [ $COUNT -gt 0 ]; then
  grep "^STATUS_${STATUS}" $TIMEF | sed "$(echo $MAINSED) \
    egrep -H '$(echo $FINDS)' vardir1_\1\/log\/master.err | egrep -v '$(echo $IGNOR)'\n \
    egrep -H '$(echo $FINDS)' vardir1_\1\/log\/bootstrap.log | egrep -v '$(echo $IGNOR)'/g" >> ./${STATUS}.sh
fi

STATUS="VALGRIND_FAILURE"; parse
if [ $COUNT -gt 0 ]; then
  grep "^STATUS_${STATUS}" $TIMEF | sed "$(echo $MAINSED) \
    egrep -H 'at 0x|by 0x|== Thread|== [A-Za-z0-9]' vardir1_\1\/log\/master.err | \
    egrep -v '[!^]==|Memcheck,|opyright|Command:|For counts|track-origins'/g" >> ./${STATUS}_FULL.sh  # Full output
  grep "^STATUS_${STATUS}" $TIMEF | sed "$(echo $MAINSED) \
    egrep -H -A3 --no-group-separator 'at 0x' vardir1_\1\/log\/master.err | \
    egrep -v 'my_malloc.c' | sed -e 's|by 0x|  by 0x|' | \
    sed 's|0x[0-9A-F]*:[\t ]||;s|(|\t\t\t\t(|;s|(.*).*\\\((.*)\\\)| \\\1|'/g" >> ./${STATUS}.sh  # 'at 0x' + few lines is much better for quick result reviews
      # Filtering our my_malloc.c just makes the stacks a bit clearer. To be eval'ed over time to see if it is not too restrictive (bugs in my_malloc.c)
fi

STATUS="CONTENT_MISMATCH_SELECT"; parse
if [ $COUNT -gt 0 ]; then
  grep "^STATUS_${STATUS}" $TIMEF | sed "$(echo $MAINSED)/g" >> ./${STATUS}.sh 
    # Need to add appropriate greps/awks here. Just added it to be able to quickly delete STATUS_CONTENT_MISMATCH_SELECT trials.
fi

STATUS="LENGTH_MISMATCH_SELECT"; parse
if [ $COUNT -gt 0 ]; then
  grep "^STATUS_${STATUS}" $TIMEF | sed "$(echo $MAINSED)/g" >> ./${STATUS}.sh 
    # Need to add appropriate greps/awks here. Just added it to be able to quickly delete STATUS_LENGTH_MISMATCH_SELECT trials.
fi

STATUS="INTERNAL_ERROR"; parse
if [ $COUNT -gt 0 ]; then
  grep "^STATUS_${STATUS}" $TIMEF | sed "$(echo $MAINSED) \
    egrep -H '.pm line [0-9]' trial\1.log | tail/g" >> ./${STATUS}.sh
fi

STATUS="UNKNOWN_ERROR"; parse
if [ $COUNT -gt 0 ]; then
  grep "^STATUS_${STATUS}" $TIMEF | sed "$(echo $MAINSED) \
    egrep -H '.pm line [0-9]' trial\1.log | tail/g" >> ./${STATUS}.sh      # May need updating (just copy/paste atm), though may work fine
fi

STATUS="ODD"; parse
if [ $COUNT -gt 0 ]; then
  grep "^STATUS_${STATUS}" $TIMEF | sed "$(echo $MAINSED) \
    egrep -H '.pm line [0-9]' trial\1.log | tail/g" >> ./${STATUS}.sh      # May need updating (just copy/paste atm), though may work fine
fi

STATUS="RECOVERY_FAILURE"; parse
if [ $COUNT -gt 0 ]; then
  grep "^STATUS_${STATUS}" $TIMEF | sed "$(echo $MAINSED) \
    egrep -H '.pm line [0-9]' trial\1.log | tail/g" >> ./${STATUS}.sh      # May need updating (just copy/paste atm), though may work fine
fi

STATUS="PERL_FAILURE"; parse
if [ $COUNT -gt 0 ]; then
  grep "^STATUS_${STATUS}" $TIMEF | sed "$(echo $MAINSED) \
    egrep -H '.pm line [0-9]' trial\1.log | tail/g" >> ./${STATUS}.sh
fi

STATUS="REPLICATION_FAILURE"; parse
if [ $COUNT -gt 0 ]; then
  grep "^STATUS_${STATUS}" $TIMEF | sed "$(echo $MAINSED) \
    egrep -H '.pm line [0-9]' trial\1.log | tail/g" >> ./${STATUS}.sh      # May need updating (just copy/paste atm), though may work fine
fi

if [ "$INPUT" != "WIPE" ]; then
  echo 'STATUS_ODD is not an RQG status, it is used here to process STATUS_RECOVERY_FAILURE trials which do not have a proper last line.'
  echo 'You definitely want to check: SERVER_CRASHED, VALGRIND, ALARM, DATABASE_CORRUPTION (in that order)'
  echo 'And you also definitely want to check: ENVIRONMENT_FAILURE, ODD - especially by using _untar script and then running: $ find . | grep core'
  echo 'To checkout all core dumps, just untar everything and then execute analyze_crashes.sh (note the es in crashES.sh) to process all cores'
  echo 'Alternatively use analyze_subdir_cores.sh (A very similar functionality script, which will output STD/FULL gdb backtraces, but not the error log.'
  echo 'However the analyze_subdir_cores.sh script is suitable for non-RQG runs also, whereas analyze_crashes.sh (which calls analyze_crash.sh) is not.)'
  echo "Remember you can also (still) use the ${SCRIPT_PWD}/cleanup_failures.sh script to cleanup sets of similar trials after analysis"
fi
[ "$INPUT" != "WIPE" ] && test "$INPUT" != "NOWIPE" && echo "And, you can also start this script again with 'WIPE' as a single option (rqg_results.sh WIPE) to clean up less important failures"

if [ "$INPUT" == "WIPE" ]; then
  if [ -x ./PERL_FAILURE_wipe.sh ]; then ./PERL_FAILURE_wipe.sh; fi
  if [ -x ./INTERNAL_ERROR_wipe.sh ]; then ./INTERNAL_ERROR_wipe.sh; fi
  if [ -x ./ENVIRONMENT_FAILURE_wipe.sh ]; then ./ENVIRONMENT_FAILURE_wipe.sh; fi
  if [ -x ./UNKNOWN_ERROR_wipe.sh ]; then ./UNKNOWN_ERROR_wipe.sh; fi
  $SCRIPT_PWD/cleanup_failures.sh SERVER_CRASHED 'Assertion .m_lock != __null && thd->mdl_context.is_lock_owner(m_namespace, "", "", MDL_SHARED). failed.' # Bug 1360064
  rm *_wipe.sh >/dev/null 2>&1
  rm *_untar.sh >/dev/null 2>&1
  $SCRIPT_PWD/cleanup_ALARMs.sh # Deletes ALARM status failed RQG trials with no important server log issues. Does not delete trials which are not untarred yet
  $SCRIPT_PWD/rqg_results.sh NOWIPE
fi

rm $TIMEF
