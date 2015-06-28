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
    if [ -e /mnt/onboard/.ScreenSaver/uninstall ]
    then
        cd /mnt/onboard/.ScreenSaver
        mv uninstall uninstalled-$(date +%Y%m%d-%H%M)
        rm -f /etc/udev/rules.d/screensaver.rules
        rm -rf /usr/local/ScreenSaver
        exit
    fi
}

uninstall_check

# 3.15.0 workaround: IconPowerView message no longer appears, instead we get this:
# nickel: QWidget(0x5d84d8, name = "infoContainer")  does not have a property named  "spacing"

oldtimestamp=$(date +%s)

logread -f | stdbuf -oL grep -E '>>> IconPowerView|nickel: QWidget.*"infoContainer".*"spacing"' | while read line
do
    # QWidget message is noisy.
    timestamp=$(date +%s)

    if [ $(($timestamp-$oldtimestamp)) -lt 10 ]
    then
        continue
    fi

    oldtimestamp=$timestamp

    # End of 3.15.0 workaround

    cd /mnt/onboard/.ScreenSaver || exit

    uninstall_check

    # show random picture
    set -- *.png
    rnd="$RANDOM$RANDOM$RANDOM"
    file=$(eval 'echo "${'$((1 + $rnd % $#))'}"')

    sleep 1
    pngshow "$file"
    sleep 1
    pngshow "$file"

    cd /
done

rmdir /tmp/ScreenSaver
