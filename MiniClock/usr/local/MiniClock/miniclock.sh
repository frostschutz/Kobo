#!/bin/sh

export LD_LIBRARY_PATH="/usr/local/MiniClock:$LD_LIBRARY_PATH"
PATH="/usr/local/MiniClock:$PATH"
BASE="/mnt/onboard/.addons/miniclock"
CONFIGFILE="$BASE/miniclock.cfg"

# udev kills slow scripts
udev_workarounds() {
    if [ "$SETSID" != "1" ]
    then
        SETSID=1 setsid "$0" "$@" &
        exit
    fi

    # udev might call twice
    mkdir /tmp/MiniClock || exit
}

# nickel stuff
wait_for_nickel() {
    while ! pidof nickel || ! grep /mnt/onboard /proc/mounts
    do
      	sleep 5
    done
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
        rm -f /etc/udev/rules.d/MiniClock.rules
        rm -rf /usr/local/MiniClock /tmp/MiniClock
        exit
    fi
}

load_config() {
    [ -z "${config_loaded:-}" ] || grep /mnt/onboard /proc/mounts || return 1 # not mounted
    config_loaded=1

    cfg_format=$(config format '%a %b %d %H:%M')
    cfg_offset_x=$(config offset_x '0')
    cfg_offset_y=$(config offset_y '0')
    cfg_font=$(config font 'IBM')
    cfg_size=$(config size '0')
    cfg_fg_color=$(config fg_color 'BLACK')
    cfg_bg_color=$(config bg_color 'WHITE')
    cfg_update=$(config update '60')
    cfg_delay=$(config delay '1')
}

update() {
    fbink -X "$cfg_offset_x" -Y "$cfg_offset_y" -F "$cfg_font" -S "$cfg_size" \
          -C "$cfg_fg_color" -B "$cfg_bg_color" \
          "$(date +"$cfg_format")"
}

update_cycle() {
    while sleep $((1 + $cfg_update - ($(date +%s) % cfg_update)))
    do
        [ -e /tmp/MiniClock ] || exit
        update
    done
}

# --- Main: ---

main() {
    udev_workarounds
    wait_for_nickel
    uninstall_check

    load_config

    update_cycle &

    while :
    do
        for i in $(seq 0 10)
        do
            cat /dev/input/event1 | dd bs=1 count=1 of=/dev/null
            sleep $cfg_delay
            update
        done
    done
}

main
