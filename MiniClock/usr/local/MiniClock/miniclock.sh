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
    [ -z "${config_loaded:-}" ] || [ "$CONFIGFILE" -nt /tmp/MiniClock -o "$CONFIGFILE" -ot /tmp/MiniClock ] || return 1 # not changed
    config_loaded=1
    touch -r "$CONFIGFILE" /tmp/MiniClock # remember timestamp

    uninstall_check

    cfg_format=$(config format '%a %b %d %H:%M')
    cfg_offset_x=$(config offset_x '0')
    cfg_offset_y=$(config offset_y '0')
    cfg_font=$(config font 'IBM')
    cfg_size=$(config size '0')
    cfg_fg_color=$(config fg_color 'BLACK')
    cfg_bg_color=$(config bg_color 'WHITE')
    cfg_update=$(config update '60')
    cfg_delay=$(config delay '1')
    cfg_repeat=$(config repeat '3')
}

update() {
    sleep 0.1
    fbink -X "$cfg_offset_x" -Y "$cfg_offset_y" -F "$cfg_font" -S "$cfg_size" \
          -C "$cfg_fg_color" -B "$cfg_bg_color" \
          "$(date +"$cfg_format")"
}

# expect X seconds for touch
# return 0 if touched
# return 1 if not touched
timeout_touch() {
    local touched="not"
    read -t "$1" touched < /dev/input/event1
    [ "$touched" != "not" ]
}

# --- Main: ---

main() {
    local i=0
    local x=0

    udev_workarounds
    wait_for_nickel

    while :
    do
        load_config
        update
        timeout_touch $((1 + $cfg_update - ($(date +%s) % $cfg_update))) || continue

        i=0
        while [ $i -lt $cfg_repeat ]
        do
            i=$(($i+1))

            update

            if timeout_touch $cfg_delay
            then
                i=0
            fi
        done
    done
}

main
