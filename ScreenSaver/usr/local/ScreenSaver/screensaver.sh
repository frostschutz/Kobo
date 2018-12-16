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
    while ! pidof nickel || ! grep /mnt/onboard /proc/mounts
    do
        sleep 1
    done

    sleep 5
}

# config parser
config() {
    local value
    value=$(grep -E -m 1 "^$1\s*=" "$CONFIGFILE" | tr -d '\r')
    value="${value:${#1}}"
    value="${value#*=}"
    shift
    [ "$value" != "" ] && echo "$value" || echo "$@"
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
    if [ ! -e /mnt/onboard/.addons/screensaver/fbset.txt ]
    then
        fbset > /mnt/onboard/.addons/screensaver/fbset.txt
    fi

    set -- $(fbset | grep geometry)
    width=$2
    height=$3
    line=$4
    vyres=$5
    depth=$6
    pixelbs=$((($depth-1)/8+1))
    widthbs=$(($width*$pixelbs))
    linebs=$(($line*$pixelbs))
}

#
# force screen refresh
#
refresh() {
    fbink -s top=0,left=0,width=$width,height=$height,wfm=GC16
}

#
# visualize the scanline
#
scanline_draw() {
    dd bs="$linebs" seek=$(($1-1)) count=1 if=/dev/urandom of=/dev/fb0
    dd bs="$linebs" seek=$(($1+1)) count=1 if=/dev/urandom of=/dev/fb0
    refresh
}

#
# grab a line of pixels from the framebuffer
#
scanline() {
    printf "%s" $(hexdump -v -s $(($1*$linebs)) -n $(($widthbs)) -e '1/4 "%x\n"' /dev/fb0 | sed -e 's@..@@' | uniq)
}

#
# automagically detect the standby scanline offset
#
scanline_standby() {
    step=5
    threshold=$(($height/10))
    prev=""
    moste_potente_line=""
    moste_potente_offset=""

    checksum="$(md5sum /dev/fb0)"

    # ignore first / last 32 lines as some readers have a dead zone
    # this is slow so check only every $step line, half the work twice the profit
    for offset in $(seq 32 $step $(($height-32)))
    do
        cur=$(scanline $offset)

        if [ "$prev" = "$cur" ]
        then
            continue
        fi

        prev="$cur"

        threshold=$(($threshold-$step))

        if [ "$threshold" -lt "0" ]
        then
            # not a standby image
            return 1
        fi

        if [ ${#cur} -gt ${#moste_potente_line} ]
        then
            # find the most significant line
            for offset in $(seq $(($offset-$step+1)) $(($offset+$step-1)))
            do
                cur=$(scanline $offset)

                if [ ${#cur} -gt ${#moste_potente_line} ]
                then
                    moste_potente_line="$cur"
                    moste_potente_offset="$offset"
                fi
            done
        fi
    done

    if [ "${#moste_potente_line}" -lt 64 ]
    then
        # blank image?
        return 2
    fi

    # framebuffer changed while scanning?
    echo "$checksum" | md5sum -c -s || return 3

    echo "$moste_potente_offset:$moste_potente_line"
}

#
# pick a random file
#
randomfile() {
    cd "$BASE"/"$1" || break
    set -- *.png
    eval 'echo "$PWD"/"${'$((1 + $RANDOM$RANDOM$RANDOM % $#))'}"'
}

#
# uptime in seconds
#
uptimesecs() {
    grep -o '^[0-9]*' /proc/uptime
}

#
# file age in seconds
#
fileage() {
    [ -e "$1" ] && echo $(( $(date +%s) - $(stat -c "%Y" "$1") ))
}

# --- Main: ---

udev_workarounds
wait_for_nickel
uninstall_check

while touch "$WATCHFILE"
do
    inotifywait -e open -e unmount "$WATCHFILE"
    error=$?

    if [ $error -gt 2 ]
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

    cfg_standby=$(config standby "")

    if [ "$cfg_standby" = "" ]
    then
        sleep 2
        cfg_standby=$(scanline_standby) || continue
        # should not reach if poweroff
        echo "
#
# Standby scanline autodetected $(date)
#   If this value does not work, remove it so it will be re-detected.
#
standby=$cfg_standby
" >> "$CONFIGFILE"

        scanline_draw ${cfg_standby%:*}
        continue
    fi

    cfg_poweroff=$(config poweroff "")

    powerfile="/usr/local/ScreenSaver/poweroff.txt"

    if [ -e "$powerfile" -a $(fileage "$powerfile") -gt $(uptimesecs) ]
    then
        cat "$powerfile" >> "$CONFIGFILE"
        rm "$powerfile"
        cfg_poweroff=$(config poweroff "")
    fi

    if [ "$cfg_poweroff" = "" ]
    then
        # autodetect poweroff scanline (using standby offset)
        offset=${cfg_standby%:*}

        for i in $(seq 1 20)
        do
            sleep 0.25
            cur=$(scanline "$offset")
            [ "$cur" = "$prev" ] && continue
            prev="$cur"
            [ "${#cur}" -lt 64 ] && continue

            # Possible candidate:
            echo "
#
# Poweroff scanline autodetected [$i] $(date)
#   If this value does not work, remove it so it will be re-detected.
#
poweroff=$offset:$cur
" > "$powerfile"
            scanline_draw $offset &
        done

        sleep 2
        wait
        rm "$powerfile" # should not reach if actually powered off
        continue
    fi

    # actually see if we can display an image

    standby=${cfg_standby#*:}
    standby_offset=${cfg_standby%:*}
    standbyfile=$(randomfile standby)
    power=${cfg_poweroff#*:}
    power_offset=${cfg_poweroff%:*}
    powerfile=$(randomfile poweroff)

    if [ ! -e "$standbyfile" -a ! -e "$powerfile" ]
    then
        # there aren't even any pictures? kill me now.
        break
    fi

    for i in $(seq 1 20)
    do
        sleep 0.25

        if [ -e "$powerfile" -a "$power" = "$(scanline "$power_offset")" ]
        then
            fbink -g file="$powerfile"
            # break # poweroff refresh wars in 4.12 firmware
        fi

        if [ -e "$standbyfile" -a "$standby" = "$(scanline "$standby_offset")" ]
        then
            fbink -g file="$standbyfile"
            break
        fi
    done
done

rmdir /tmp/ScreenSaver
