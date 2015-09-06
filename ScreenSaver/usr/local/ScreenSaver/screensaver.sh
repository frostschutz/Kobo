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

PATH="/usr/local/ScreenSaver:$PATH"
CONFIGFILE="/mnt/onboard/.addons/screensaver/screensaver.cfg"

#
# configuration
#
config() {
    local value
    value=$(grep "^$1=" "$CONFIGFILE")
    value="${value:$((1+${#1}))}"
    [ "$value" != "" ] && echo "$value" || echo "$2"
}


# install default config file
if [ -e /usr/local/ScreenSaver/screensaver.cfg ]
then
    mv -n /usr/local/ScreenSaver/screensaver.cfg "$CONFIGFILE"
    mv /usr/local/ScreenSaver/screensaver.cfg "$CONFIGFILE".$(date +%Y%m%d-%H%M)
fi

install_symlink() {
    if [ "$(readlink /sbin/dd)" != "/usr/local/ScreenSaver/dd.sh" ]
    then
        rm /sbin/dd
        ln -s /usr/local/ScreenSaver/dd.sh /sbin/dd
    fi
}

uninstall_symlink() {
    if [ "$(readlink /sbin/dd)" = "/usr/local/ScreenSaver/dd.sh" ]
    then
        rm /sbin/dd
    fi
}

uninstall_check() {
    if [ "$(config uninstall 0)" = "1" ]
    then
        mkdir -p /mnt/onboard/.addons/screensaver/uninstalled-$(date +%Y%m%d-%H%M)
        rm -f /etc/udev/rules.d/screensaver.rules
        rm -rf /usr/local/ScreenSaver
        uninstall_symlink
        exit
    fi
}

uninstall_check

if [ "$(config method)" = "scanline" ]
then
    install_symlink
else
    uninstall_symlink
fi

if [ "$(config method logread)" = "logread" ]
then
    exec /usr/local/ScreenSaver/logread.sh
fi
