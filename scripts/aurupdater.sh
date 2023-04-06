#!/usr/bin/env bash

set -x

if cat /etc/passwd | grep "x:1000" > /dev/null; then
    tempuser=$(cat /etc/passwd | grep "x:1000" | awk '{print $1}')
    user=${tempuser%%:*}
else
    user=$(whoami)
fi

echo "Durchsuche auf neue Packete indem fremde Packete angezeigt werden!!!"

# for-schleife
for wort in $(pacman -Qmq)
do
    echo "$wort"
    if [ -d "/home/${user}/aur-builds/${wort}" ];then
        /usr/bin/aurinstaller ${wort}
    fi
done
