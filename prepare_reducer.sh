#!/bin/bash
# Created by Roel Van de Paar, Percona LLC

# To aid with correct bug to testcase generation, this script creates a local run script for reducer and sets #VARMOD#.
# This handles crashes/asserts for the moment only. Could be expanded later for other cases, and to handle more unforseen situations.

SCRIPT_PWD=$(cd `dirname $0` && pwd)
WORKD_PWD=$PWD

# startup.sh will be handled by the script as well, so remove it here.
if [ "" == "$1" ]; then
  echo "This script creates a local run script for reducer. It expects one parameter: the trial number to analyze"
  echo "Optionally, one may pass a secondary option. This will stop prepare_reducer.sh from enabling some of it's features:"
  echo "  1: Disable query-from-core extraction from the orginal trial run (handy if an older Percona server download was wiped, for example)"
  echo "  2: Disable query-from-core extraction from the cmdtrace trial run (not often used, but handy if cmdtrace failed to reproduce issue but you expect that (somehow) the resulting reducer.sh script will still reproduce the issue. Note: this is unlikely.)"
  echo "  3: Disable all query-from-core extraction methods (handy if there are no core files at all) (Also handy for VALGRIND issues, though support for Valgrind is not fully added yet - you will need to manually edit the resulting reducer.sh script and set the right mode and TEXT string. Btw, remember that for Valgrind reductions, MODE=1 is required, not MODE=3/4 - another change necessary in the resulting reducer.sh, in the machine variables section)" 
  echo "Example usage:"
  echo "./prepare_reducer.sh 10 1  # Would create a reducer10.sh whilst not checking for queries in the core (if any) of the original trial run"
  echo "Note: it usually is best not to use the second option. It's only there in case you need prepare_reducer.sh to work and somehow are missing"
  echo "something, for example a core file or you may have (accidentally) deleted the old Percona server download and are testing with a newer"
  echo "download using cmdtrace - in which case extraction from the core produced by the cmdtrace file would be handy, but the original core - though"
  echo "there - could not sucessfully be read by this script as the original mysqld is no longer there."
  echo "Also note that prepare_reducer.sh uses the basedir from the cmdtrace file (as at the time this script is executed) as the basedir for the"
  echo "resulting reducer.sh script. If you instead want to use the basedir from the original trial run (if it is at all different), change it in"
  echo "the machine variables section of the resulting reducer.sh script."
  exit 1
else
  TRIAL=$1
  if [ "" == "$2" ]; then
    SKIP=0
  else
    SKIP=$2
  fi
  if [ ! -r ./cmdtrace${TRIAL} ]; then
    echo "Something is wrong: ./cmdtrace${TRIAL} does not exist or cannot be read?"
    echo "Try running ${SCRIPT_PWD}/startup.sh ${TRIAL} to generate ./cmdtrace${TRIAL}"
    echo "Note that an SQL trace is also necessary for this script, so execute ./cmdtrace${TRIAL} first to generate an ${TRIAL}.sql file"
    echo "Note also that the ./cmdtrace${TRIAL} result should be a crash/assert also (just like the original trial 92 - assuming it was a crash/assert) - otherwise the SQL trace is likely (though not always) invalid."
    exit 1
  elif [ ! -d ./vardir1_${TRIAL} ]; then
    if [ -r ./vardir1_${TRIAL}.tar.gz ]; then
      tar -xf ./vardir1_${TRIAL}.tar.gz
      if [ ! -d ./vardir1_${TRIAL} ]; then
        echo "Something is wrong: ./vardir1_${TRIAL} does not exist?"
        echo "However, ./vardir1_${TRIAL}.tar.gz exists, and we tried extracting it, but it seemed to have failed?"
        exit 1
      fi 
    else
      echo "Something is wrong: ./vardir1_${TRIAL} nor ./vardir1_${TRIAL}.tar.gz exists?"
      exit 1
    fi
  fi
  if [ ! -r ./trial${TRIAL}.log ]; then
    echo "Something is wrong: the trial log ./trial_${TRIAL}.log does not exist or is not readable by this script?"
    exit 1
  elif [ ! -r ./vardir1_${TRIAL}/log/master.err ]; then
    echo "Something is wrong: the mysqld error log ./vardir1_${TRIAL}/log/master.err does not exist or is not readable by this script?"
    exit 1
  elif [ ! -r ./${TRIAL}.sql ]; then
    echo "Something is wrong: there is no (script readable) ./${TRIAL}.sql present. Did you execute ./cmdtrace${TRIAL} first to generate a ${TRIAL}.sql SQL trace file?"
    echo "Note also that the ./cmdtrace${TRIAL} result should be a crash/assert also - otherwise the SQL trace is likely (though not 'perfectly always') invalid."
    exit 1
  fi
  REDUCER=`cat ./cmdtrace${TRIAL} | grep "cd.*/randgen" | sed 's|cd ||;s|$|/util/reducer/reducer.sh|'`
  if [ ! -r ${REDUCER} ]; then
    echo "Something is wrong: there is no (script readable) reducer.sh at ${REDUCER}, please check!"
    exit 1
  fi
fi

if [ $SKIP -ne 1 ]; then
  BASE=`grep -m1 "Starting.*basedir" ./trial${TRIAL}.log | sed 's|^.*basedir=/|/|;s| .*$||'`
  echo "BASE directory original trial: ${BASE}"
fi
# We always need to know BASE2 directory, as MYBASE is set to the same in reducer.sh
BASE2=`grep -m1 'basedir=' ./cmdtrace${TRIAL} | sed 's|^.*basedir=/|/|;s| .*$||'`
echo "BASE directory cmdtrace trial: ${BASE2}"

if [ $SKIP -lt 3 ]; then
  if [ $SKIP -ne 1 ]; then
    cd ${WORKD_PWD}/vardir1_${TRIAL}/master-data >/dev/null 
    CORE=`ls -1 *core* 2>&1 | head -n1 | grep -v "No such file"`
    if [ "" == "${CORE}" ]; then
      echo "Something is wrong: there is no [vg]core in ./vardir1_${TRIAL}/master-data/ ?"
      echo "You may want to re-run ./prepare_reducer.sh with '1' as a second option. Run ./prepare_reducer.sh without options to read more about this."
      exit 1
    else
      CORE=${PWD}/${CORE}
      echo "CORE file original trial: ${CORE}"
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
          echo "You may want to re-run ./prepare_reducer.sh with a secondary option. Run ./prepare_reducer.sh without options to read more about this."
          exit 1
        fi
      else
        echo "Something is wrong: there is no (script readable) mysqld binary at ${BASE}/bin/mysqld ?"
        echo "You may want to re-run ./prepare_reducer.sh with a secondary option. Run ./prepare_reducer.sh without options to read more about this."
        exit 1
      fi
    fi
    echo "BIN file  original trial: ${BIN}"
  fi
  if [ $SKIP -ne 2 ]; then
    cd ${WORKD_PWD}/rundir1_${TRIAL}/master-data >/dev/null 
    CORE2=`ls -1 *core* 2>&1 | head -n1 | grep -v "No such file"`
    if [ "" == "${CORE2}" ]; then
      echo "Something is wrong: there is no [vg]core in ./rundir1_${TRIAL}/master-data/ ?"
      echo "You may want to re-run ./prepare_reducer.sh with '2' as a second option, though this is not commonly done. Run ./prepare_reducer.sh without options to read more about this."
      exit 1
    else
      CORE2=${PWD}/${CORE2}
      echo "CORE file cmdtrace trial: ${CORE2}"
    fi
    if [ -r ${BASE2}/bin/mysqld ]; then
      BIN2=${BASE2}/bin/mysqld
    else
      # Check if this is a debug build by checking if debug string is present in dirname
      if [[ ${BASE2} = *debug* ]]; then
        if [ -r ${BASE2}/bin/mysqld-debug ]; then
          BIN2=${BASE2}/bin/mysqld-debug
        else
          echo "Something is wrong: there is no (script readable) mysqld binary at ${BASE2}/bin/mysqld[-debug] ?"
          echo "You may want to re-run ./prepare_reducer.sh with a secondary option. Run ./prepare_reducer.sh without options to read more about this."
          exit 1
        fi
      else
        echo "Something is wrong: there is no (script readable) mysqld binary at ${BASE2}/bin/mysqld ?"
        echo "You may want to re-run ./prepare_reducer.sh with a secondary option. Run ./prepare_reducer.sh without options to read more about this."
        exit 1
      fi
    fi
    echo "BIN file  cmdtrace trial: ${BIN2}"
  fi
fi
cd ${WORKD_PWD}

echo "* Parsing the SQL trace generated by ./cmdtrace${TRIAL}"
rm -f ${TRIAL}b.sql ${TRIAL}c.sql
touch ${TRIAL}c.sql
${SCRIPT_PWD}/parse_general_log.pl -i${TRIAL}.sql -o${TRIAL}b.sql

# Extract all queries that were running from the cores (of the original trial and the cmdtrace version thereof) 
if [ $SKIP -lt 3 ]; then
  echo "* Obtaining quer(y)(ies) which were running at the time of the crash from the core dump(s) and adding them to the SQL trace"
  if [ $SKIP -ne 1 ]; then
    echo "** Core dump quer(y)(ies) from the original trial (core: ${CORE})"
    rm -f /tmp/gdb_PARSE.txt
    # For debugging purposes, remove ">/dev/null 2>&1" on the next line and observe output
    gdb ${BIN} ${CORE} >/dev/null 2>&1 < ${SCRIPT_PWD}/extract_query.gdb
    for i in {1..3}; do
      BEFORESIZE=`cat ./${TRIAL}c.sql | wc -l`
      # The double quotes ; ; are to prevent parsing mishaps where the query is invalid and has opened a multi-line situation
      grep '^\$' /tmp/gdb_PARSE.txt | sed 's/^[\$0-9a-fx =]*"//;s/"$//;s/[ \t]*$//;s|\\"|"|g;s/$/; ;/' | grep -v '^\$' >> ./${TRIAL}c.sql
      AFTERSIZE=`cat ./${TRIAL}c.sql | wc -l`
    done
    echo "  > $[ $AFTERSIZE - $BEFORESIZE ] quer(y)(ies) added 3x to the SQL trace"
  fi
  if [ $SKIP -ne 2 ]; then
    echo "** Core dump quer(y)(ies) from the cmdrun trial (core: ${CORE2})"
    rm -f /tmp/gdb_PARSE.txt
    gdb ${BIN2} ${CORE2} >/dev/null 2>&1 < ${SCRIPT_PWD}/extract_query.gdb
    for i in {1..3}; do
      BEFORESIZE=`cat ./${TRIAL}c.sql | wc -l`
      # The double quotes ; ; are to prevent parsing mishaps where the query is invalid and has opened a multi-line situation
      grep '^\$' /tmp/gdb_PARSE.txt | sed 's/^[\$0-9a-fx =]*"//;s/"$//;s/[ \t]*$//;s|\\"|"|g;s/$/; ;/' | grep -v '^\$' >> ./${TRIAL}c.sql
      AFTERSIZE=`cat ./${TRIAL}c.sql | wc -l`
    done
    echo "  > $[ $AFTERSIZE - $BEFORESIZE ] quer(y)(ies) added 3x to the SQL trace"
  fi
fi

# Extract the "Query:" crashed query from the error log (making sure we have the 'Query:' one at the end)
echo "* Obtaining quer(y)(ies) which was marked (by mysqld) as causing the crash from the mysqld error log (if any) and adding them to the SQL trace"
for i in {1..3}; do
  BEFORESIZE=`cat ./${TRIAL}c.sql | wc -l`
  grep "Query ([x0-9a-fA-F]*):" ${WORKD_PWD}/vardir1_${TRIAL}/log/master.err | sed 's|^Query ([x0-9a-fA-F]*): ||;s|$|; ;|' >> ./${TRIAL}c.sql  # ; ; : see above
  AFTERSIZE=`cat ./${TRIAL}c.sql | wc -l`
done
echo "  > $[ $AFTERSIZE - $BEFORESIZE ] quer(y)(ies) added 3x to the SQL trace"

# Extract all "connection lost" queries from RQG log
echo "* Obtaining 'connection lost' quer(y)(ies) from the RQG log (if any) and adding them to the SQL trace"
for i in {1..3}; do
  BEFORESIZE=`cat ./${TRIAL}c.sql | wc -l`
  cat trial${TRIAL}.log | grep "2013 Lost connection" | sed 's|^.*:[0-9][0-9] Query: [ ]*||;s|[ ]*failed: 2013 Lost connection.*$|; ;|' >> ./${TRIAL}c.sql # ; ; : see above
  AFTERSIZE=`cat ./${TRIAL}c.sql | wc -l`
done
echo "  > $[ $AFTERSIZE - $BEFORESIZE ] quer(y)(ies) added 3x to the SQL trace"

# Merge ${TRIAL}c.sql to ${TRIAL}b.sql and report on both
cat ./${TRIAL}c.sql >> ./${TRIAL}b.sql
echo ">> All crashing queries were merged to ./${TRIAL}b.sql"
echo ">> A SQL file with only the crashing queries was also saved as ./${TRIAL}c.sql (which is handy to directly execute from the CLI after using ./start_mtr{TRIAL})"

# Compile 'mysqld options used' string
echo "* Parsing mysqld options used in RQG run and adding them to MYEXTRA string in reducer.sh"
${SCRIPT_PWD}/myextra.sh ${TRIAL}  # This is to show the output of myextra.sh
MYEXTRA=`${SCRIPT_PWD}/myextra.sh ${TRIAL} | grep "^MYEXTRA"`  # This is to grab the actual MYEXTRA string

# Prepare reducer.sh
TEXT=`${SCRIPT_PWD}/text_string.sh ${WORKD_PWD}/vardir1_${TRIAL}/log/master.err`
if [ "$TEXT" != "[ \t]*" -a "$TEXT" != "" ]; then  # TEXT string was found/compiled succesfully in live above
  cat ${REDUCER} \
    | sed -e "0,/#VARMOD#/s:#VARMOD#:MODE=3\n#VARMOD#:" \
    | sed -e "0,/#VARMOD#/s:#VARMOD#:TEXT=\"${TEXT}\"\n#VARMOD#:" \
    | sed -e "0,/#VARMOD#/s:#VARMOD#:MYBASE=\"${BASE2}\"\n#VARMOD#:" \
    | sed -e "0,/#VARMOD#/s:#VARMOD#:INPUTFILE=\"${TRIAL}b.sql\"\n#VARMOD#:" \
    | sed -e "0,/#VARMOD#/s:#VARMOD#:${MYEXTRA}\n#VARMOD#:" \
    > ./reducer${TRIAL}.sh
  echo "* Note: the issue-specific text search string that prepare_reducer.sh found was '${TEXT}'. The TEXT variable has been set to this in the machine section of ./reducer${TRIAL}.sh. This suggested text string was taken from the mysqld error log through issue string analysis. If this text should not be suitable as to the issue you are looking for, please edit ./reducer${TRIAL}.sh (machien variable section) to change it."
else
  cat ${REDUCER} \
    | sed -e "0,/#VARMOD#/s:#VARMOD#:MODE=4\n#VARMOD#:" \
    | sed -e "0,/#VARMOD#/s:#VARMOD#:MYBASE=\"${BASE2}\"\n#VARMOD#:" \
    | sed -e "0,/#VARMOD#/s:#VARMOD#:INPUTFILE=\"${TRIAL}b.sql\"\n#VARMOD#:" \
    | sed -e "0,/#VARMOD#/s:#VARMOD#:${MYEXTRA}\n#VARMOD#:" \
    > ./reducer${TRIAL}.sh
  echo "* Note: at the moment, reducer${TRIAL}.sh will run with MODE=4 (looking for any crash) as it did not find any usable TEXT string to use. However, you may change this to MODE=3 and use some issue-specific text excerpt from the error log."
fi
echo "General note: It is often better to use MODE=3 to look for specific crahes, as it avoids a 'rogue' crash (an often-seen crash which is not getting fixed for quite some time) from misleading reducer in MODE=4 (which looks for any crash). Alternatively, for example in the case of an assert, you can set the TEXT variable to some substring of the assert message. It is recommended to keep the string short and free from special characters, for example: 'm_can_overwrite' - a function name shown in the much longer assert message - would be good. Finally, for MODE=4 no TEXT variable needs to be set (if it is set, it is ignored) since MODE=4 looks for any crash."

chmod +x ./reducer${TRIAL}.sh

echo -e "\nDone!! Start reducer like this: ./reducer${TRIAL}.sh (we've already set the input file to be ${TRIAL}b.sql using the INPUTFILE variable in reducer)"
echo "Both reducer and the SQL trace file have been pre-prepped with all the right settings and all crashing queries, ready for you to use!"
echo -e "\nIMPORTANT!! Remember that settings pre-programmed into reducer${TRIAL}.sh by this script are in the 'Machine configurable variables' section, not"
echo "in the 'User configurable variables' section. As such, and for example, if you want to change the settings (for example change MODE=4 to MODE=3), then"
echo "please make such changes in the 'Machine configurable variables' section which is a bit lower in the file (search for 'Machine' to find it easily)."
echo "Any changes you make in the 'User configurable variables' section will not take effect as the Machine sections overwrites these!"
