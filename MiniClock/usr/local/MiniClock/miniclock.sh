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

    cfg_touchscreen=$(config touchscreen '1')
    cfg_button=$(config button '0')

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
    cfg_truetype_padding=$(config truetype_padding '1')

    cfg_nightmode_file=$(config nightmode_file '/mnt/onboard/.kobo/nightmode.ini')
    cfg_nightmode_key=$(config nightmode_key 'invertActive')
    cfg_nightmode_value=$(config nightmode_value 'yes')

    cfg_battery_min=$(config battery_min '0')
    cfg_battery_max=$(config battery_max '50')
    cfg_battery_source=$(config battery_source '/sys/devices/platform/pmic_battery.1/power_supply/mc13892_bat/capacity')

    cfg_days=$(config days '')
    cfg_months=$(config months '')

    # backward support for deprecated settings:

    # delay=1 repeat=3 -> delay=1 1 1
    cfg_repeat=$(config repeat '')
    if [ "$cfg_repeat" != "" ]
    then
        set -- $cfg_delay
        if [ $# -eq 1 -a "$cfg_repeat" -gt 1 ]
        then
            cfg_delay=""
            for i in $(seq 1 "$cfg_repeat")
            do
                cfg_delay="$cfg_delay $1"
            done
        fi
    fi

    # calculated settings:

    # delta for sharp idle update
    set -- $cfg_delay
    cfg_delta=$(($1+1))
    cfg_delta=${cfg_delta:-0}

    # padding is spaces for now
    if [ "$cfg_truetype_padding" != "0" ]
    then
        cfg_truetype_format=" $cfg_truetype_format "
    fi

    # localization shenaniganizer
    my_date() {
        date "$@"
    }

    my_tt_date() {
        date "$@"
    }

    case "$cfg_format" in
        *{*)
        my_date() {
            shenaniganize_date "$@"
        }
        ;;
    esac

    case "$cfg_truetype_format" in
        *{*)
        my_tt_date() {
            shenaniganize_date "$@"
        }
        ;;
    esac

    # patch handling
    if [ ! -e /tmp/MiniClock/patch -a "$cfg_button" == "1" ]
    then
        touch /tmp/MiniClock/patch

        libnickel=$(realpath /usr/local/Kobo/libnickel.so)
        if strings "$libnickel" | grep -F '/dev/input/event0:keymap=keys/device.qmap:grab=1'
        then
            sed -i -e 's@/dev/input/event0:keymap=keys/device.qmap:grab=1@/dev/input/event0:keymap=keys/device.qmap:grab=0@' "$libnickel"
            touch /tmp/MiniClock/reboot
        fi
    fi
}

# string replace str a b
str_replace() {
    local pre
    local post
    pre=${1%%"$2"*}
    post=${1#*"$2"}
    echo "$pre$3$post"
}

# shenaniganize date
shenaniganize_date() {
    local datestr=$(date "$@")
    local pre post number

    # shenaniganize all the stuff
    for i in $(seq 100) # terminate on invalid strings
    do
        case "$datestr" in
            *{battery}*)
                battery=$(cat "$cfg_battery_source")
                if [ $? -eq 0 -a "$battery" -ge "$cfg_battery_min" -a "$battery" -le "$cfg_battery_max" ]
                then
                    battery="$battery""%%"
                else
                    battery=""
                fi
                datestr=$(str_replace "$datestr" "{battery}" "$battery")
            ;;
            *{day}*)
                set -- "" $cfg_days
                day=$(date +%u)
                shift $day
                datestr=$(str_replace "$datestr" "{day}" "$1")
            ;;
            *{month}*)
                set -- "" $cfg_months
                month=$(date +%m)
                shift $month
                datestr=$(str_replace "$datestr" "{month}" "$1")
            ;;
            *)
                echo "$datestr"
                return
            ;;
        esac
    done
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
    mkdir /tmp/MiniClock/update || return

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
              "$(my_tt_date +"$cfg_truetype_format")"

        [ $? -eq 0 ] && rmdir /tmp/MiniClock/update && exit # return
    fi

    # fbink with builtin font
    fbink -X "$cfg_offset_x" -Y "$cfg_offset_y" -F "$cfg_font" -S "$cfg_size" \
          -C "$cfg_fg_color" -B "$cfg_bg_color" \
          $nightmode \
          "$(my_date +"$cfg_format")"

    ) # subshell end / unblock

    [ -e /tmp/MiniClock/reboot ] && fbink "MiniClock: Please Reboot for Button Patch"

    rmdir /tmp/MiniClock/update
}

# expect X seconds for touch
# return 0 if touched
# return 1 if not touched
timeout_touch() {
    local touched="not"
    read -t "$1" touched < "$2"
    [ "$touched" != "not" ]
}

# --- Main: ---

main() {
    local i=0
    local x=0

    udev_workarounds
    wait_for_nickel
    mkfifo /tmp/MiniClock/loop

    while [ -p /tmp/MiniClock/loop ]
    do
        load_config
        nightmode_check

        if [ "$cfg_touchscreen" = 1 ]
        then
        (
           mkdir /tmp/MiniClock/touchscreen || exit
           timeout_touch $((1 + $cfg_update - ( ($(date +%s)+$cfg_delta) % $cfg_update))) /dev/input/event1

           for i in $cfg_delay
           do
               sleep $i
               update
           done
           rmdir /tmp/MiniClock/touchscreen
           echo next > /tmp/MiniClock/loop
       ) &
       fi

       if [ "$cfg_button" = 1 ]
       then
       (
           mkdir /tmp/MiniClock/button || exit
           timeout_touch $((1 + $cfg_update - ( ($(date +%s)+$cfg_delta) % $cfg_update))) /dev/input/event0

           for i in $cfg_delay
           do
               sleep $i
               update
           done
           rmdir /tmp/MiniClock/button
           echo next > /tmp/MiniClock/loop
       ) &
       fi

       if [ "$cfg_touchscreen" = 0 -a "$cfg_button" = 0 ]
       then
       (
           mkdir /tmp/MiniClock/frequency || exit
           sleep $(( ($(date +%s)+$cfg_delta) % $cfg_update ))
           update
           rmdir /tmp/MiniClock/frequency
           echo next > /tmp/MiniClock/loop
       ) &
       fi

       read -t $cfg_update next < /tmp/MiniClock/loop
    done
}

main
