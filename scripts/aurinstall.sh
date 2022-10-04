#!/usr/bin/env bash

set -x

if cat /etc/passwd | grep "x:1000" > /dev/null; then
    tempuser=$(cat /etc/passwd | grep "x:1000" | awk '{print $1}')
    user=${tempuser%%:*}
else
    user=$(whoami)
fi

url="$1"
packagename=${url##*/}
mkdir -p /home/${user}/aur-builds
cd /home/${user}/aur-builds
pwd

function aurinstaller() {
    if git clone ${url}; then
        echo "git erfolgreich runtergeladen!!!"
    else
        echo "verändere URL zum erfolgreichen herunterladen!!!"
        git clone "https://aur.archlinux.org/${url}.git"
    fi
    echo "Erstelle Dateirechte"
    chmod 777 -R ${packagename}
    cd ${packagename}


}

if [ -d ${packagename} ];then
    echo "Bereits vorhanden!!!"
    cd ${packagename}
    git reset --hard
else
    aurinstaller
fi

function aurinstallwithoutroot() {
    makepkg -si --skipchecksums --skippgpcheck --nocheck --noconfirm --install --needed
}

function aurinstallwithroot() {
    su "${user}" -c "makepkg -si --skipchecksums --skippgpcheck --nocheck --noconfirm --install --needed"
}

if ! [[ $EUID -ne 0 ]]; then
    run=aurinstallwithroot
else
    run=aurinstallwithoutroot
fi

if $run; then
    echo "Installation von ${packagename} erfolgreich beendet!!!"
else
    echo "Installation von ${packagename} fehlgeschlagen!!!"
    echo "Bitte bearbeite in den nächsten 5 Sekunden bei bedarf die PKGBUILD für einen erneuten versuch"
    echo "Speichern sie dann die Datei mit STRG + X und dann y"
    sleep 5
    # Vim läppert manchmal nicht 
    nano -w PKGBUILD

    n=1
    if [[ $EUID -ne 0 ]]; then
        while ! makepkg -si --skipchecksums --skippgpcheck --nocheck --noconfirm --install --needed; do
            echo "restart!!!"
            if [ "$n" == "4" ]; then
                echo "terminated"
                echo "versuche manuelle Installation!!!"
                sudo pacman -U $(echo $(find /home/${user}/aur-builds/${packagename}/ -name "*zst") | cut -d" " -f1)
                break
            fi
            echo "Position: $n"
            (( n++ ))
        done
    else
        while ! su "${user}" -c "makepkg -si --skipchecksums --skippgpcheck --nocheck --noconfirm --install --needed"; do
            echo "restart!!!"
            if [ "$n" == "4" ]; then
                echo "terminated"
                echo "versuche manuelle Installation!!!"
                pacman -U $(echo $(find /home/${user}/aur-builds/${packagename}/ -name "*zst") | cut -d" " -f1)
                break
            fi
            echo "Position: $n"
            (( n++ ))
        done
    fi

fi

echo "Fertig!!!"
