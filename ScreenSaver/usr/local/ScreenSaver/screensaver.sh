#!/bin/sh

export PATH="/usr/local/ScreenSaver:$PATH"
export LD_LIBRARY_PATH="/usr/local/ScreenSaver:$LD_LIBRARY_PATH"

BASE="/mnt/onboard/.addons/screensaver"
CONFIGFILE="$BASE/screensaver.cfg"
WATCHFILE="/mnt/onboard/.kobo/affiliate.conf"

udev_workarounds() {
    # udev kills slow scripts
    if [ "$SETSID" != "1" ]
    then
        SETSID=1 setsid "$0" "$@" &
        exit
    fi

    # udev might call twice
    mkdir /tmp/ScreenSaver || exit
}

wait_for_nickel() {
    while ! pidof nickel || [ ! -e /mnt/onboard/.kobo ]
    do
        sleep 1
    done

    sleep 5
}

config() {
    local value
    value=$(grep -m 1 "^$1=" "$CONFIGFILE")
    value="${value:$((1+${#1}))}"
    [ "$value" != "" ] && echo "$value" || echo "$2"
}

uninstall_check() {
    if [ "$(config uninstall 0)" = "1" ]
    then
        mv "$CONFIGFILE" "$BASE"/uninstalled-$(date +%Y%m%d-%H%M).cfg
        rm -f /etc/udev/rules.d/screensaver.rules
        rm -rf /usr/local/ScreenSaver
        rm /sbin/dd
        rmdir /tmp/ScreenSaver
        exit
    fi
}

#
# set framebuffer geometry variables
#
geometry() {
    set -- $(fbset | grep geometry)
    width=$2
    widthbs=$(($2*2))
    height=$3
    line=$4
    linebs=$(($4*2))
}

#
# check for white line
#
standby() {
    [ "$(hexdump -s $(($1*$linebs)) -n $(($widthbs)) -e '1/2 "%04x"' /dev/fb0)" = "ffff*" ]
}

#
# check for black line
#
poweroff() {
    [ "$(hexdump -s $(($1*$linebs)) -n $(($widthbs)) -e '1/2 "%04x"' /dev/fb0)" = "0000*" ]
}

#
# pick a random file
#
randomfile() {
    cd "$BASE"/"$1" || break
    set -- *.png
    eval 'echo "$PWD"/"${'$((1 + $RANDOM$RANDOM$RANDOM % $#))'}"'
}

# --- Main: ---

udev_workarounds
wait_for_nickel
uninstall_check

while touch "$WATCHFILE"
do
    inotifywait -e open -e unmount "$WATCHFILE"

    if [ $? -gt 2 ]
    then
        # unknown error condition
        break
    fi

    if [ ! -e "$WATCHFILE" ]
    then
        # presumably unmounted
        break
    fi

    geometry

    sleep 1

    if standby 101 && standby 211 && standby 307 && standby 401 \
       && standby 151 && standby 251 && standby 353 && standby 457
    then
        pngshow "$(randomfile standby)"
    elif poweroff 101 && poweroff 211 && poweroff 307 && poweroff 401
    then
        pngshow "$(randomfile poweroff)"
    fi
done

rmdir /tmp/ScreenSaver
