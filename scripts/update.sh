#!/usr/bin/env bash

set -ex
user=$(whoami)

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
    sudo "${0}" "$@"
    exit 0
fi
echo "Als root Angemeldet"

version="${1}"

git config --global credential.helper store
repo=SpectreOS
repo1=shell-scripte-code
arch=$(uname -m)
branch=master

# Aktualisiere die Repositiories
if [ -f "/opt/${repo}/repo.sh" ]; then
  /opt/${repo}/repo.sh
else
  /usr/bin/repo-script
fi
source /etc/environment

if [ -d "/opt/${repo}" ]; then
        echo "${repo} existiert bereits!!!"
        cd /opt/${repo}
        git checkout ${branch}
        if ! git remote set-url origin ${WEBADDRESS_OS}; then
           git remote add origin ${WEBADDRESS_OS}
        fi
        git pull
    else
        git clone -b ${branch} ${WEBADDRESS_OS} /opt/${repo}
    fi
    if [ -d "/opt/${repo1}" ]; then
        echo "${repo1} existiert bereits!!!"
        cd /opt/${repo1}
        if ! git remote set-url origin ${WEBADDRESS_SCRIPTE}; then
           git remote add origin ${WEBADDRESS_SCRIPTE}
        fi
        git pull
    else
        git clone ${WEBADDRESS_SCRIPTE} /opt/${repo1}
    fi
cd /

cp /opt/${repo}/arch-graphical-install-auto.sh /usr/bin/arch-graphical-install-auto
/usr/bin/arch-graphical-install-auto

echo "Fertig!!!"
