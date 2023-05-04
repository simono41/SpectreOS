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

function download_repo() {
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

# Überprüfe ob es eine neue Version gibt
function checkversion() {
    installed_version=$(LC_ALL=C pacman -Qi ${packagename} | awk '/^Version/{print $3}' | awk -F- '{ print $1 }')
    new_version=$(awk --field-separator='=' '/^pkgver/{print $2}' PKGBUILD | head -n1 | sed -e "s/'//g" -e "s/\"//g")
    # Überprüfe ob eine Version bereits installiert ist
    if [ -n "$installed_version" ]; then
        if [ "$new_version" = "$installed_version" ]; then
            echo "Es existiert zurzeit keine neuere Version"
            exit 0
        fi
    fi
}

function aurinstallwithoutroot() {
    makepkg -si --skipchecksums --skippgpcheck --nocheck --noconfirm --install --needed
}

function aurinstallwithroot() {
    su "${user}" -c "makepkg -si --skipchecksums --skippgpcheck --nocheck --noconfirm --install --needed"
}

if [ -d ${packagename} ];then
    echo "Bereits vorhanden!!!"
    cd ${packagename}
    git pull
    checkversion
    git clean -fdx
    #git reset --hard
else
    download_repo
fi

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
