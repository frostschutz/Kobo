#!/bin/sh

# udev kills slow scripts
if [ "$SETSID" != "1" ]
then
    SETSID=1 setsid "$0" "$@" &
    exit
fi

# wait for nickel
while sleep 10
do
    pidof nickel && break
done

# udev might call twice
mkdir /tmp/ScreenSaver || exit

# ScreenSaver by waiting for syslog event

PATH="/usr/local/ScreenSaver:$PATH"

uninstall_check() {
    if [ -e /mnt/onboard/.addons/screensaver/uninstall ]
    then
        cd /mnt/onboard/.addons/screensaver
        mv uninstall uninstalled-$(date +%Y%m%d-%H%M)
        rm -f /etc/udev/rules.d/screensaver.rules
        rm -rf /usr/local/ScreenSaver
        exit
    fi
}

uninstall_check

rmdir /tmp/ScreenSaver
