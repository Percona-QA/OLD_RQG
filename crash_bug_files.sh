#!/bin/bash
# Created by Roel Van de Paar, Percona LLC

# This script quickly gathers all files required for logging a crash bug report

if [ "" == "$1" ]; then
  echo "This scrip quickly gathers all files required for logging a crash bug report. It expects one parameter: a crashed trial number"
  exit 1
else
  TRIAL=$1
  if [ ! -r ./trial${TRIAL}.log ]; then
    echo "Something is wrong: ./trial${TRIAL}.log does not exist or cannot be read?"
    exit 1
  else
    if [ ! -r ./vardir1_${TRIAL}.tar.gz ]; then
      echo "Something is wrong: ./vardir1_${TRIAL}.tar.gz does not exist or cannot be read?"
      exit 1
    fi
  fi
fi

if [ -d ./vardir1_$1 ]; then
  echo "=== Accidental erroneous vardir1_$1 deletion prevention ==="
  echo "Note that this script overwrites ./vardir1_$1 (which already exists). In 99% of the cases this is fine,"
  echo "however if you already made changes to ./vardir1_$1 (and want to preserve them) hit CTRL+C now."
  echo "Hit enter twice (to continue) or CTRL-C (to abort) now."
  read -p "Hit enter or CTRL-C now:"
  read -p "Hit enter or CTRL-C now:"
fi

SCRIPT_PWD=$(cd `dirname $0` && pwd)
WORKD_PWD=$PWD

# Make a bundle dir which will contain all files
BUNDLE_DIR=${WORKD_PWD}/BUNDLE_${TRIAL}

# Cleanup existing BUNDLE directory
if [ -d ${BUNDLE_DIR} ]; then
  cd ${BUNDLE_DIR}
  if [ "" != "$(pwd | grep 'BUNDLE_')" ]; then     # Safety mechanism to ensure ${BUNDLE_DIR} contains "BUNDLE_" and that it can be entered 
    cd ..
    rm -Rf ${BUNDLE_DIR}
  fi
fi

mkdir ${BUNDLE_DIR}
cd ${BUNDLE_DIR}
if [ "" == "$(pwd | grep 'BUNDLE_')" ]; then
  echo "Something is wrong: tried to create '${BUNDLE_DIR}' and changedir (cd) to it, but that failed"
  exit 1
fi
cd ${WORKD_PWD}

# Extract vardir, create cmd file (to get cmd<trial> command file)
echo "Running startup.sh..."
$(echo -e "\n\n") | ${SCRIPT_PWD}/startup.sh ${TRIAL} man > /dev/null
cp cmd${TRIAL} ${BUNDLE_DIR}

# Analyze crash (to get STD, FULL stacktraces and error log)
echo "Running analyze_crash.sh..."
${SCRIPT_PWD}/analyze_crash.sh ${TRIAL} > /dev/null
mv gdb_${TRIAL}_* ${BUNDLE_DIR}
mv master_${TRIAL}_* ${BUNDLE_DIR}

# Run script (to get mysqld binary, ldd dependency files and core file)
echo "Running core_retrieve.sh..."
${SCRIPT_PWD}/core_retrieve.sh ${TRIAL} > /dev/null
mv core_${TRIAL}_* ${BUNDLE_DIR}

# Grammar file analysis (to get relevant grammar file)
echo "Fetching grammar files..."
YYGRAMMAR=$(grep "grammar" cmd${TRIAL} | sed "s|.*grammar=||;s| .*||")
ZZGRAMMAR=$(grep "gendata" cmd${TRIAL} | sed "s|.*gendata=||;s| .*||")
if [ "conf" == "$(echo $YYGRAMMAR | sed 's|^[./]*conf.*|conf|')" ]; then  # Need to prefix RQG dir since there was no full path used in cmd file
  YYGRAMMAR=$(grep "randgen" cmd${TRIAL} | grep -m1 "cd" | sed "s/cd //")$(echo $YYGRAMMAR | sed 's|^[./]*|/|')
fi
if [ "conf" == "$(echo $ZZGRAMMAR | sed 's|^[./]*conf.*|conf|')" ]; then  # Need to prefix RQG dir since there was no full path used in cmd file
  ZZGRAMMAR=$(grep "randgen" cmd${TRIAL} | grep -m1 "cd" | sed "s/cd //")$(echo $ZZGRAMMAR | sed 's|^[./]*|/|')
fi
YYALTGRAM=$(echo $YYGRAMMAR | sed "s|.*/\(.*.yy\)|$WORKD_PWD/KEEP/\1|")
ZZALTGRAM=$(echo $ZZGRAMMAR | sed "s|.*/\(.*.yy\)|$WORKD_PWD/KEEP/\1|")
if [ -r $YYGRAMMAR ]; then
  cp $YYGRAMMAR ${BUNDLE_DIR}
elif [ -r $YYALTGRAM ]; then
  cp $YYALTGRAM ${BUNDLE_DIR}
else
  echo ".yy Grammar $YYGRAMMAR (or $YYALTGRAM) was regrettably not found"
fi  
if [ -r $ZZGRAMMAR ]; then
  cp $ZZGRAMMAR ${BUNDLE_DIR}
elif [ -r $ZZALTGRAM ]; then
  cp $ZZALTGRAM ${BUNDLE_DIR}
else
  echo ".zz Grammar $ZZGRAMMAR (or $ZZALTGRAM) was regrettably not found"
fi  

# Server + RQG bzr version checks
echo "Fetching bzr versions..."
cd ${BUNDLE_DIR}
echo "Server Version: " > versions.txt
FOR_VER=$(ls -1 gdb*.txt 2>&1 | head -n1 | grep -v "No such file")  # Grab a filename, later to be used for bzr version extraction
if [ "" != "${FOR_VER}" ]; then
  SVR_VER_FILE=$(grep -m1 "do_command.*/sql/sql_parse" ${FOR_VER} | sed 's|.* at ||;s|/sql/sql_parse.cc:.*||;s|\(.*\)/.*|\1|;s|_dbg||;s|_val||;s|_opt||')/.bzr/branch/last-revision 
  if [ -r $SVR_VER_FILE ]; then 
    cat $SVR_VER_FILE >> versions.txt
  fi
fi
if [ -r ../${TRIAL}.sql ]; then
  grep "mysqld" ../${TRIAL}.sql | grep -i "version" | sed 's|started with.||' >> versions.txt
fi
if [ -r ../trial${TRIAL}.log ]; then
  grep "Version" ../trial${TRIAL}.log | tr '\n' ' ' >> versions.txt
fi
echo -e "\nRQG Version: " >> versions.txt
grep "randgen Rev" ../trial${TRIAL}.log | sed 's|.*Rev.*: ||' | tr '\n' ' ' >> versions.txt
echo "" >> versions.txt

# Copying in vardir tarball without core file
echo "Adding vardir tarball without core (as core is already included in core_* tarball)..."
cd ${WORKD_PWD}
rm -Rf temp_core_store
mkdir temp_core_store
cd temp_core_store
if [ "" == "$(pwd | grep 'temp_core_store')" ]; then
  echo "Something is wrong: tried to create '${WORKD_PWD}/temp_core_store' and changedir (cd) to it, but that failed"
  exit 1
fi
cd ${WORKD_PWD}
cp ./vardir1_${TRIAL}/master-data/*core* ./temp_core_store   # Temporary move core out of the way
rm -f ./vardir1_${TRIAL}/master-data/*core*
# Copy ib_logfiles from _epoch directory if innodb_log_group_home_dir location is different
IBLOG_LOC=`grep innodb_log_group_home_dir ${WORKD_PWD}/vardir1_${TRIAL}/command | sed -r 's/.*innodb_log_group_home_dir=(\S+).*/\1/'`
if [ -n "$IBLOG_LOC" ];then
  cp $IBLOG_LOC/* ./vardir1_${TRIAL}/master-data
fi
tar -zhcf ${BUNDLE_DIR}/vardir1_${TRIAL}.tar.gz ./vardir1_${TRIAL}/*
mv ./temp_core_store/*core* ./vardir1_${TRIAL}/master-data   # Move core back
rm -Rf ./temp_core_store

# Copy in trial log
cp trial${TRIAL}.log ${BUNDLE_DIR}

# Bundle it up
echo "Bundling the lot into BUNDLE_${TRIAL}.tar.gz"
tar -zhcpf BUNDLE_${TRIAL}.tar.gz ${BUNDLE_DIR}

# Report outcome
echo -e "\nDONE! Successfully created bundle for trial ${TRIAL} at ${BUNDLE_DIR}, and tarred up the lot as BUNDLE_${TRIAL}.tar.gz"
