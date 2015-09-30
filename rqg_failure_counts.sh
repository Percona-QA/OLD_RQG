#!/bin/bash
##########################
# Check RQG failure status
##########################

# Get script directory
SCRIPT_PWD=$(cd `dirname $0` && pwd)

MAIL="/bin/mail"
BUILD_TAG=$2
# Get RQG work directory
if [ -z $1 ]; then
  echo "No valid parameter was passed. Need relative RQG workdir.. Retry.";
  echo "Usage example:"
  echo "$./rqg_failure_counts.sh <RQG workdir>"
  echo "$WORKDIR would be used to test the RQG failure"
  exit 1
else
  WORKDIR=$1
fi

# Check if workspace was set by Jenkins, otherwise this is presumably a local run
if [ -z $WORKSPACE ]; then
  echo "Assuming this is a local (i.e. non-Jenkins initiated) run."
  WORKSPACE=$WORKDIR
fi

cd $WORKDIR

# get latest RQG work log directory
RQGDIR=`ls -lt --time-style="long-iso"  | egrep '^d'  | awk '{print $8}' | egrep -E '^[0-9]+$' | head -1`
cd $RQGDIR

# Remove known failures from RQG
${SCRIPT_PWD}/cleanup_known.sh

# get outcome of rqg run
${SCRIPT_PWD}/rqg_results.sh
echo $WORKDIR
if ls -1 *untar.sh &> /dev/null; then
    ls -1 *untar.sh > $WORKDIR/rqg_failure_count.txt
else
    >$WORKDIR/rqg_failure_count.txt
fi

ACTUAL_FAILURE=()
for i in $(cat /$WORKDIR/rqg_failure_count.txt) ; do
  ACTUAL_FAILURE+=${i%_untar*}
done

FAILURE_INFO=(ALARM SERVER_CRASHED DATABASE_CORRUPTION ENVIRONMENT_FAILURE VALGRIND_FAILURE CONTENT_MISMATCH_SELECT LENGTH_MISMATCH_SELECT INTERNAL_ERROR UNKNOWN_ERROR ODD RECOVERY_FAILURE PERL_FAILURE)
FAILURE_INFO1=(ALARM SERVER_CRASHED DATABASE_CORRUPTION VALGRIND_FAILURE CONTENT_MISMATCH_SELECT LENGTH_MISMATCH_SELECT)
FAILURE_INFO2=(INTERNAL_ERROR UNKNOWN_ERROR ODD RECOVERY_FAILURE PERL_FAILURE ENVIRONMENT_FAILURE)
## RQG run info to XML for Jenkins

rm -rf $WORKSPACE/rqg_results.log

echo "Storing RQG failure in $WORKDIR"
echo '<?xml version="1.0" encoding="UTF-8"?>' > $WORKSPACE/rqg_results_plot1.xml
echo '<?xml version="1.0" encoding="UTF-8"?>' > $WORKSPACE/rqg_results_plot2.xml
echo '<?xml version="1.0" encoding="UTF-8"?>' > $WORKSPACE/rqg_results.xml
echo '<rqg>' >> $WORKSPACE/rqg_results.xml
echo '<rqg>' >> $WORKSPACE/rqg_results_plot1.xml
echo '<rqg>' >> $WORKSPACE/rqg_results_plot2.xml
for k in ${FAILURE_INFO[@]}; do
 if [[ ${ACTUAL_FAILURE[*]} =~ $k ]]
 then
  COUNT=`cat $k* | grep "Count:" | tr -d [:alpha:] |tr -d [:punct:] | tr -d [:space:]`
#  let TOTAL+=$COUNT
  if [[ ${FAILURE_INFO1[*]} =~ $k ]]
  then
   echo "  <$k  type=\"result\">$COUNT</$k>"  >> $WORKSPACE/rqg_results_plot1.xml
  fi
  if [[ ${FAILURE_INFO2[*]} =~ $k ]]
  then
   echo "  <$k  type=\"result\">$COUNT</$k>"  >> $WORKSPACE/rqg_results_plot2.xml
  fi
  echo "  <$k type=\"result\">$COUNT</$k>"  >> $WORKSPACE/rqg_results.xml
  printf "%-25s |%-10d\n" $k $COUNT  >> $WORKSPACE/rqg_results.log
 else
  if [[ ${FAILURE_INFO1[*]} =~ $k ]]
  then
   echo "  <$k type=\"result\">0</$k>"  >> $WORKSPACE/rqg_results_plot1.xml
  fi
  if [[ ${FAILURE_INFO2[*]} =~ $k ]]
  then
   echo "  <$k type=\"result\">0</$k>"  >> $WORKSPACE/rqg_results_plot2.xml
  fi
  echo "  <$k type=\"result\">0</$k>"  >> $WORKSPACE/rqg_results.xml
  printf "%-25s |%-10d\n" $k 0  >> $WORKSPACE/rqg_results.log
 fi
done
echo '</rqg>' >> $WORKSPACE/rqg_results_plot1.xml
echo '</rqg>' >> $WORKSPACE/rqg_results_plot2.xml
echo '</rqg>' >> $WORKSPACE/rqg_results.xml

## Permanent logging
cp $WORKSPACE/rqg_results_plot1.xml $WORKSPACE/rqg_results_plot1_`date +"%F_%H%M"`.xml
cp $WORKSPACE/rqg_results_plot2.xml $WORKSPACE/rqg_results_plot2_`date +"%F_%H%M"`.xml
cp $WORKSPACE/rqg_results.xml $WORKSPACE/rqg_results_`date +"%F_%H%M"`.xml

## Send mail with RQG failure count
cat $WORKSPACE/rqg_results.log | $MAIL -s "RQG failure count - $BUILD_TAG" ramesh.sivaraman@percona.com
