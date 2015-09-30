#!/bin/bash
# Created by Roel Van de Paar, Percona LLC

# parse_times.sh allows one to check the start and end times for all trials within a RQG combinations.pl run directory. 
# This allows for quick analysis to see if any of the trials stalled/hanged/locked up by reviewing the durations

COUNT=$(ls *.log | wc -l)
if [ $COUNT -gt 0 ]; then
  for LOG in *.log; do 
    T1=$(head -n1 $LOG|cut -b1-21|sed 's/[^0-9:T-]//g')
    T2=$(tail -n1000 $LOG|sort -r|grep -m1 "201[3-9]-[0-9]"|cut -b1-21|sed 's/[^0-9:T-]//g')
    S1=$(date +%s -d "$T1")
    S2=$(date +%s -d "$T2")
    DIFF=$(( $S2 - $S1 ))
    PARSED_DIFF=$(echo $DIFF | awk '{printf "%.2d:%.2d:%.2d\n",$1/3600,$1%3600/60,$1%60}')
    echo -e "$LOG\t$T1 - $T2:\t$PARSED_DIFF run time"
  done
fi
