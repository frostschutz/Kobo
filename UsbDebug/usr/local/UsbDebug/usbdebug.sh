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
    | grep -E '^([^ ]+ ){6}b30[39]' ||
    grep -E ' failure.* /mnt/(onboard|sd) ' /tmp/usbdebug-umount
}

showface() {
    if isbusy > /tmp/UsbDebug.tmp
    then
        mv /tmp/usbdebug-umount /tmp/UsbDebug.umount
        mv /tmp/UsbDebug.tmp /tmp/UsbDebug.log
        pngshow /usr/local/UsbDebug/sadface.png
        sleep 1
        pngshow /usr/local/UsbDebug/sadface.png
        sleep 1
        pngshow /usr/local/UsbDebug/sadface.png
    else
        pngshow /usr/local/UsbDebug/happyface.png
        sleep 1
        pngshow /usr/local/UsbDebug/happyface.png
        sleep 1
        pngshow /usr/local/UsbDebug/happyface.png
    fi
}

udev_workarounds

if [ "$ACTION" == "add" ]
then
    mkdir "/tmp/UsbDebug" || exit

    timeout=30 # ~ 5 minutes

    while [ -e /tmp/UsbDebug -a "$timeout" -gt 0 ]
    do
        timeout=$(($timeout-1))
        showface
        sleep 10
    done
elif [ "$ACTION" == "remove" ]
then
    rm -rf "/tmp/UsbDebug"

    while sleep 1
    do
        if [ -e "/mnt/onboard/.kobo/KoboReader.sqlite" ]
        then
            mkdir /mnt/onboard/.usbdebug
            cp /tmp/UsbDebug.* /mnt/onboard/.usbdebug

            if [ -e /mnt/onboard/.usbdebug/uninstall ]
            then
                rm -f /etc/udev/rules.d/usbdebug.rules
                rm -rf /usr/local/UsbDebug
            fi

            exit
        fi
    done
fi
