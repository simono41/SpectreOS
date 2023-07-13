#!/usr/bin/env bash

set -x

if cat /etc/passwd | grep "x:1000" > /dev/null; then
    tempuser=$(cat /etc/passwd | grep "x:1000" | awk '{print $1}')
    user=${tempuser%%:*}
else
    user=$(whoami)
fi

echo "Durchsuche auf neue Packete indem fremde Packete angezeigt werden!!!"

# for-schleife für verwaiste Packete vom AUR
for wort in $(pacman -Qmq)
do
    echo "$wort"
    /usr/bin/aurinstaller ${wort}
done
