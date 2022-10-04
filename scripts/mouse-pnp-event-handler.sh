#!/usr/bin/env bash
## $1 = "add" / "remove"
## $2 = %k from udev

## Set TRACKPAD_NAME according to your configuration.
## Check your trackpad name with:
## find /sys/class/input/ -name mouse* -exec udevadm info -a {} \; | grep 'ATTRS{name}'
#TRACKPAD_NAME="SynPS/2 Synaptics TouchPad"
#TRACKPAD_NAME="ELAN0501:00 04F3:3060 Touchpad"
temptrackpad="$(find /sys/class/input/ -name mouse* -exec udevadm info -a {} \; | grep 'ATTRS{name}' -m 1)"
TRACKPAD_NAME="${temptrackpad:18:$((${#temptrackpad})) - 19}"

USERLIST=$(w -h | cut -d' ' -f1 | sort | uniq)
MOUSELIST=$(find /sys/class/input/ -name mouse*)

for CUR_USER in ${USERLIST}; do
    CUR_USER_XAUTH="$(sudo -Hiu ${CUR_USER} env | grep -e "^HOME=" | cut -d'=' -f2)/.Xauthority"


    ## Can't find a way to get another users DISPLAY variable from an isolated root environment. Have to set it manually.
    #CUR_USER_DISPL="$(sudo -Hiu ${CUR_USER} env | grep -e "^DISPLAY=" | cut -d'=' -f2)"
    CUR_USER_DISPL=":0"

    export XAUTHORITY="${CUR_USER_XAUTH}"
    export DISPLAY="${CUR_USER_DISPL}"

    if [ -f "${CUR_USER_XAUTH}" ]; then
        case "$1" in
            "add")
                echo "${TRACKPAD_NAME}" > /tmp/trackpad
                /usr/bin/synclient TouchpadOff=1
                /usr/bin/logger "USB mouse plugged. Disabling touchpad for $CUR_USER. ($XAUTHORITY - $DISPLAY)"
                ;;
            "remove")
                ## Only execute synclient if there are no external USB mice connected to the system.
                EXT_MOUSE_FOUND="0"
                for CUR_MOUSE in ${MOUSELIST}; do
                    if [ "$(cat ${CUR_MOUSE}/device/name)" != "$(cat /tmp/trackpad)" ]; then
                        EXT_MOUSE_FOUND="1"
                    fi
                done
                if [ "${EXT_MOUSE_FOUND}" == "0" ]; then
                    /usr/bin/synclient TouchpadOff=0
                    /usr/bin/logger "No additional external mice found. Enabling touchpad for $CUR_USER."
                else
                    logger "Additional external mice found. Won't enable touchpad yet for $CUR_USER."
                fi
                ;;
        esac
    fi
done
