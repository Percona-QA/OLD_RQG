#!/bin/bash
# Created by Roel Van de Paar, Percona LLC

# Note that the analyze_subdir_cores.sh script is suitable for non-RQG runs also, whereas analyze_crashes.sh (which calls analyze_crash.sh) is not.

SCRIPT_PWD=$(cd `dirname $0` && pwd)

# OLD find . | grep core | sed 's|.*vardir1_|~/percona_qa/analyze_crash.sh |;s|/master-data.*||'

find . | grep core | sed 's|.*vardir1_||;s|/master-data.*||' | xargs -Inr $SCRIPT_PWD/analyze_crash.sh nr
