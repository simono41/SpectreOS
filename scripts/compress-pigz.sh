#!/usr/bin/env bash

set -ex

archiv=$2

# https://codepre.com/de/pigz-comprime-y-descomprime-archivos-en-paralelo-en-linux.html
if [ "make" == "$1" ]; then
    while (( "$(expr $# - 2)" ))
    do

        dateien="$3 ${dateien}"

        shift

    done

    tar --use-compress-program=pigz -cf ${archiv} ${dateien}

elif [ "restore" == "$1" ]; then

    pfad=$3
    [[ -z "${pfad}" ]] && pfad="."

    tar --use-compress-program=pigz -xf ${archiv} -C ${pfad}

else
    echo "tar.gz compress-script"
    echo "./compress.sh make/restore archivname.tar.gz input/output"
    echo "./compress.sh make archivname.tar.zst daten"
    echo "./compress.sh restore archivname ort"
fi
