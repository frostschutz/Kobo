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

showface() {
    grep -E '^/dev/mmcblk(0p3|1p1) ' /proc/mounts \
    && pngshow /usr/local/UsbDebug/sadface.png \
    || pngshow /usr/local/UsbDebug/happyface.png
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
