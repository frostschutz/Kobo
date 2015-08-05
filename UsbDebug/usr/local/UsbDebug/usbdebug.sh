#!/bin/sh

PATH="/usr/local/UsbDebug":"$PATH"

udev_workarounds() {
    # udev kills slow scripts
    if [ "$SETSID" != "1" ]
    then
        SETSID=1 setsid "$0" "$@" &
        exit
    fi
}

isbusy() {
    grep -E '^/dev/mmcblk(0p3|1p1) ' /proc/mounts || \
    grep -E '^([^ ]+ ){3}b3:0[39] ' /proc/*/maps || \
    find /proc/[0-9]*/cwd /proc/[0-9]*/fd -exec stat -tL {} + \
    | grep -E '^([^ ]+ ){6}b30[39]'
}

showface() {
    if isbusy > /tmp/UsbDebug.tmp
    then
        mv /tmp/UsbDebug.tmp /tmp/UsbDebug.log
        pngshow /usr/local/UsbDebug/sadface.png
    else
        pngshow /usr/local/UsbDebug/happyface.png
    fi
}

udev_workarounds

if [ "$ACTION" == "add" ]
then
    mkdir "/tmp/UsbDebug" || exit

    timeout=300 # 5 minutes

    while [ -e /tmp/UsbDebug -a "$timeout" -gt 0 ]
    do
        timeout=$(($timeout-1))
        showface
        sleep 1
    done
elif [ "$ACTION" == "remove" ]
then
    rm -rf "/tmp/UsbDebug"
fi
