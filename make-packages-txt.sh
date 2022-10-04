#!/usr/bin/env bash

set -ex

pacman -Qq > $1

# Packete die ignoriert werden können, in diesem Falle Spiele und verweiste Packete
fill="$(pacman -Qqm) widelands megaglest megaglest-data openra openbve freeciv minetest minetest-server teeworlds 0ad 0ad-data"

while (( "$(expr $#)" ))
do
    for wort in ${fill}
    do
        if grep ${wort} $1; then
            grep -v "${wort}" $1 > tempdatei
            mv tempdatei $1
        else
            echo "überspringe ${wort}"
        fi
    done
    shift
done
