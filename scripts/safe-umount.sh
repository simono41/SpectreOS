#!/usr/bin/env bash

set -ex

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
    sudo $0 $1 $2 $3 $4 $5 $6 $7 $8 $9
    exit 0
fi
echo "Als root Angemeldet"

device="$1"
[[ -z "${device}" ]] && device=/dev/sdb

while [[ -n "${device}" ]]
do

    for wort in $(cat /proc/mounts | grep ${device}${m2ssd} | awk '{print $1}'); do
        if cat /proc/mounts | grep ${wort} > /dev/null; then
            umount ${wort}
        fi
    done
    shift

done
