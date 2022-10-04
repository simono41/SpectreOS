#!/usr/bin/env bash

set -ex

archiv=$2

# https://linuxconfig.org/how-to-install-and-use-zstd-compression-tool-on-linux
if [ "make" == "$1" ]; then
    while (( "$(expr $# - 2)" ))
    do

        dateien="$3 ${dateien}"

        shift

    done

    tar -I 'zstd -c -T0 --ultra -20 -' -cf ${archiv} ${dateien}

elif [ "restore" == "$1" ]; then

    pfad=$3
    [[ -z "${pfad}" ]] && pfad="."

    tar --use-compress-program=unzstd -xf ${archiv} -C ${pfad}

else
    echo "tar.zst compress-script"
    echo "./compress.sh make/restore archivname.tar.zst input/output"
    echo "./compress.sh make archivname.tar.zst daten"
    echo "./compress.sh restore archivname ort"
fi
