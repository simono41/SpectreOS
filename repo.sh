#!/bin/bash
set -ex

ENVLOCAL="/etc/environment"
export WEBADDRESS_OS="https://code.brothertec.eu/simono41/SpectreOS.git"
export WEBADDRESS_SCRIPTE="https://code.brothertec.eu/simono41/shell-scripte-code.git"

if grep 'WEBADDRESS_OS' $ENVLOCAL; then
   sed -i 's|WEBADDRESS_OS=.*|WEBADDRESS_OS='$WEBADDRESS_OS'|' $ENVLOCAL
else
   echo "WEBADDRESS_OS=${WEBADDRESS_OS}" >> $ENVLOCAL
fi

if grep 'WEBADDRESS_SCRIPTE' $ENVLOCAL; then
   sed -i 's|WEBADDRESS_SCRIPTE=.*|WEBADDRESS_SCRIPTE='$WEBADDRESS_SCRIPTE'|' $ENVLOCAL
else
   echo "WEBADDRESS_SCRIPTE=${WEBADDRESS_SCRIPTE}" >> $ENVLOCAL
fi

# Lese die Umgebungsvariablen neu
source /etc/environment
