#!/bin/sh

PATH="/usr/local/ScreenSaver:$PATH"

# 3.15.0 workaround: IconPowerView message no longer appears, instead we get this:
# nickel: QWidget(0x5d84d8, name = "infoContainer") does not have a property named

oldtimestamp=""

logread -f | stdbuf -oL grep -E '>>> IconPowerView|nickel: QWidget.*"infoContainer".*does not have' | while read month day hour line
do
    # QWidget message is noisy.
    timestamp="$month$day$hour"

    if [ "$line" = "" -o "$timestamp" = "$oldtimestamp" ]
    then
        continue
    fi

    oldtimestamp="$timestamp"

    # End of 3.15.0 workaround

    cd /mnt/onboard/.addons/screensaver || exit

    uninstall_check

    # show random picture
    set -- *.png
    rnd="$RANDOM$RANDOM$RANDOM"
    file="$(eval 'echo "${'$((1 + $rnd % $#))'}"')"

    (
        pngshow "$file" &
        sleep 0.6
        pngshow "$file" &
        sleep 0.6
        pngshow "$file"
    ) &

    cd /
done
