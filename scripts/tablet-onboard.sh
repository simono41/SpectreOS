#!/usr/bin/env bash
#
set -ex

while true
do
    FTB=`ps -e | grep onboard | wc -l`
    if [ "$FTB" == 0 ]; then
        /usr/bin/onboard
    else
        echo "onboard already started"
    fi

    sleep 10
done
