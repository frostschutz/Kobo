#!/bin/sh

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

pattern=$(config pattern)

logread -f | stdbuf -oL grep -E "$pattern" | while read month day hour line
do
    # Log message is noisy.
    timestamp="$month$day$hour"

    if [ "$line" = "" -o "$timestamp" = "$oldtimestamp" ]
    then
        continue
    fi

    oldtimestamp="$timestamp"

    cd /mnt/onboard/.addons/screensaver || exit

    # show random picture
    set -- *.png
    rnd="$RANDOM$RANDOM$RANDOM"
    file="$(eval 'echo "${'$((1 + $rnd % $#))'}"')"

    for delay in $(config delay 0)
    do
        sleep $delay
        pngshow "$file" &
    done

    wait

    cd /
done
