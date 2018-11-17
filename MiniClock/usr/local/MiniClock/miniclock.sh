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
    local key value
    key=$(grep -E "^$1\s*=" "$CONFIGFILE")
    if [ $? -eq 0 ]
    then
        value=$(printf "%s" "$key" | tail -n 1 | sed -r -e 's@^[^=]*=\s*@@' -e 's@\s+(#.*|)$@@')
        echo "$value"
    else
        shift
        echo "$@"
    fi
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
    cfg_delay=$(config delay '1 1 1')

    cfg_truetype=$(config truetype '')
    cfg_truetype_size=$(config truetype_size '16')
    cfg_truetype_x=$(config truetype_x "$cfg_offset_x")
    cfg_truetype_y=$(config truetype_y "$cfg_offset_y")
    cfg_truetype_fg=$(config truetype_fg "$cfg_fg_color")
    cfg_truetype_bg=$(config truetype_bg "$cfg_bg_color")
    cfg_truetype_format=$(config truetype_format "$cfg_format")
    cfg_truetype_bold=$(config truetype_bold '')
    cfg_truetype_italic=$(config truetype_italic '')
    cfg_truetype_bolditalic=$(config truetype_bolditalic '')

    cfg_nightmode_file=$(config nightmode_file '/mnt/onboard/.kobo/nightmode.ini')
    cfg_nightmode_key=$(config nightmode_key 'invertActive')
    cfg_nightmode_value=$(config nightmode_value 'yes')

    # backward support for deprecated setting
    # delay=1 repeat=3 -> delay=1 1 1
    cfg_repeat=$(config repeat '')
    if [ "$cfg_repeat" != "" ]
    then
        set -- $cfg_delay
        if [ $# -eq 1 -a "$cfg_repeat" -ge 1 ]
        then
            cfg_delay=""
            for i in $(seq 1 "$cfg_repeat")
            do
                cfg_delay="$cfg_delay $1"
            done
        fi
    fi
}

# nightmode check
nightmode_check() {
    [ ! -e /tmp/MiniClock/nightmode ] && touch /tmp/MiniClock/nightmode

    if [ "$cfg_nightmode_file" -nt /tmp/MiniClock/nightmode -o "$cfg_nightmode_file" -ot /tmp/MiniClock/nightmode ]
    then
        # nightmode state might have changed
        nightmode=$(CONFIGFILE="$cfg_nightmode_file" config "$cfg_nightmode_key" "not $cfg_nightmode_value")

        if [ "$nightmode" = "$cfg_nightmode_value" ]
        then
            nightmode="--invert"
        else
            nightmode=""
        fi

        # remember timestamp so we don't have to do this every time
        touch -r "$cfg_nightmode_file" /tmp/MiniClock/nightmode
    fi
}

update() {
    sleep 0.1

    ( # subshell

    cd "$BASE" # blocks USB lazy-umount and cd / doesn't work

    if [ -f "$cfg_truetype" ]
    then
        # variants available?
        truetype="regular=$cfg_truetype"
        [ -f "$cfg_truetype_bold" ] && truetype="$truetype,bold=$cfg_truetype_bold"
        [ -f "$cfg_truetype_italic" ] && truetype="$truetype,italic=$cfg_truetype_italic"
        [ -f "$cfg_truetype_bolditalic" ] && truetype="$truetype,bolditalic=$cfg_truetype_bolditalic"

        # fbink with truetype font
        fbink --truetype "$truetype",size="$cfg_truetype_size",top="$cfg_truetype_y",bottom=0,left="$cfg_truetype_x",right=0,format \
              -C "$cfg_truetype_fg" -B "$cfg_truetype_bg" \
              $nightmode \
              "$(date +"$cfg_truetype_format")"

        [ $? -eq 0 ] && exit # return
    fi

    # fbink with builtin font
    fbink -X "$cfg_offset_x" -Y "$cfg_offset_y" -F "$cfg_font" -S "$cfg_size" \
          -C "$cfg_fg_color" -B "$cfg_bg_color" \
          $nightmode \
          "$(date +"$cfg_format")"

    ) # subshell end / unblock
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
        nightmode_check

        timeout_touch $((1 + $cfg_update - ($(date +%s) % $cfg_update)))

        for i in $cfg_delay
        do
            sleep $i
            update
        done
    done
}

main
