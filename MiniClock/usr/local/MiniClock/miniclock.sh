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
    cfg_debug=$(config debug '0')

    cfg_touchscreen=$(config touchscreen '1')
    cfg_button=$(config button '0')

    cfg_whitelist=$(config whitelist 'ABS:MT_POSITION_X ABS:MT_POSITION_Y KEY:F23 KEY:F24 KEY:POWER')
    cfg_cooldown=$(config cooldown '3 30')

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

    case "$cfg_format $cfg_truetype_format" in
        *{debug}*) cfg_causality=1 ;;
        *)         cfg_causality=0 ;;
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

    # whitelist filtering (string to number)
    set -- $cfg_whitelist
    cfg_whitelist=""
    for item in $@
    do
        set -- ${item//:/ }
        [ $# != 2 ] && continue
        set -- $(input_event_str2int $1 $2)
        [ $# != 2 ] && continue
        cfg_whitelist="$cfg_whitelist $1:$2"
    done
}

# string replace str a b
str_replace() {
    local pre
    local post
    pre=${1%%"$2"*}
    post=${1#*"$2"}
    echo "$pre$3$post"
}

# shenaniganize date (runs in a subshell)
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
                    battery="${battery}%"
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
            *{debug}*)
                read uptime runtime < /proc/uptime
                datestr=$(str_replace "$datestr" "{debug}" "[${causality} @ ${uptime}]")
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

        [ $? -eq 0 ] && exit # return
    fi

    # fbink with builtin font
    fbink -X "$cfg_offset_x" -Y "$cfg_offset_y" -F "$cfg_font" -S "$cfg_size" \
          -C "$cfg_fg_color" -B "$cfg_bg_color" \
          $nightmode \
          "$(my_date +"$cfg_format")"

    ) # subshell end / unblock

    [ -e /tmp/MiniClock/reboot ] && fbink "MiniClock: Please Reboot for Button Patch"
}

# --- Input Event Helpers: ---

EV="SYN KEY REL ABS MSC SW 0x6 0x7 0x8 0x9 0xa 0xb 0xc 0xd 0xe 0xf 0x10 LED SND 0x13 REP FF PWR FF_STATUS"
EV_SYN="REPORT CONFIG MT_REPORT DROPPED"
EV_KEY="RESERVED ESC 1 2 3 4 5 6 7 8 9 0 MINUS EQUAL BACKSPACE TAB Q W E R T Y U I O P LEFTBRACE RIGHTBRACE ENTER LEFTCTRL A S D F G H J K L SEMICOLON APOSTROPHE GRAVE LEFTSHIFT BACKSLASH Z X C V B N M COMMA DOT SLASH RIGHTSHIFT KPASTERISK LEFTALT SPACE CAPSLOCK F1 F2 F3 F4 F5 F6 F7 F8 F9 F10 NUMLOCK SCROLLLOCK KP7 KP8 KP9 KPMINUS KP4 KP5 KP6 KPPLUS KP1 KP2 KP3 KP0 KPDOT 0x54 ZENKAKUHANKAKU 102ND F11 F12 RO KATAKANA HIRAGANA HENKAN KATAKANAHIRAGANA MUHENKAN KPJPCOMMA KPENTER RIGHTCTRL KPSLASH SYSRQ RIGHTALT LINEFEED HOME UP PAGEUP LEFT RIGHT END DOWN PAGEDOWN INSERT DELETE MACRO MUTE VOLUMEDOWN VOLUMEUP POWER KPEQUAL KPPLUSMINUS PAUSE SCALE KPCOMMA HANGEUL HANJA YEN LEFTMETA RIGHTMETA COMPOSE STOP AGAIN PROPS UNDO FRONT COPY OPEN PASTE FIND CUT HELP MENU CALC SETUP SLEEP WAKEUP FILE SENDFILE DELETEFILE XFER PROG1 PROG2 WWW MSDOS COFFEE ROTATE_DISPLAY CYCLEWINDOWS MAIL BOOKMARKS COMPUTER BACK FORWARD CLOSECD EJECTCD EJECTCLOSECD NEXTSONG PLAYPAUSE PREVIOUSSONG STOPCD RECORD REWIND PHONE ISO CONFIG HOMEPAGE REFRESH EXIT MOVE EDIT SCROLLUP SCROLLDOWN KPLEFTPAREN KPRIGHTPAREN NEW REDO F13 F14 F15 F16 F17 F18 F19 F20 F21 F22 F23 F24 0xc3 0xc4 0xc5 0xc6 0xc7 PLAYCD PAUSECD PROG3 PROG4 DASHBOARD SUSPEND CLOSE PLAY FASTFORWARD BASSBOOST PRINT HP CAMERA SOUND QUESTION EMAIL CHAT SEARCH CONNECT FINANCE SPORT SHOP ALTERASE CANCEL BRIGHTNESSDOWN BRIGHTNESSUP MEDIA SWITCHVIDEOMODE KBDILLUMTOGGLE KBDILLUMDOWN KBDILLUMUP SEND REPLY FORWARDMAIL SAVE DOCUMENTS BATTERY BLUETOOTH WLAN UWB UNKNOWN VIDEO_NEXT VIDEO_PREV BRIGHTNESS_CYCLE BRIGHTNESS_AUTO DISPLAY_OFF WWAN RFKILL MICMUTE 0xf9 0xfa 0xfb 0xfc 0xfd 0xfe 0xff BTN_0 BTN_1 BTN_2 BTN_3 BTN_4 BTN_5 BTN_6 BTN_7 BTN_8 BTN_9 0x10a 0x10b 0x10c 0x10d 0x10e 0x10f BTN_LEFT BTN_RIGHT BTN_MIDDLE BTN_SIDE BTN_EXTRA BTN_FORWARD BTN_BACK BTN_TASK 0x118 0x119 0x11a 0x11b 0x11c 0x11d 0x11e 0x11f BTN_TRIGGER BTN_THUMB BTN_THUMB2 BTN_TOP BTN_TOP2 BTN_PINKIE BTN_BASE BTN_BASE2 BTN_BASE3 BTN_BASE4 0x12a 0x12b 0x12c 0x12d 0x12e 0x12f BTN_SOUTH BTN_EAST BTN_C BTN_NORTH BTN_WEST BTN_Z BTN_TL BTN_TR BTN_TL2 BTN_TR2 0x13a 0x13b 0x13c 0x13d 0x13e 0x13f BTN_TOOL_PEN BTN_TOOL_RUBBER BTN_TOOL_BRUSH BTN_TOOL_PENCIL BTN_TOOL_AIRBRUSH BTN_TOOL_FINGER BTN_TOOL_MOUSE BTN_TOOL_LENS BTN_TOOL_QUINTTAP BTN_STYLUS3 0x14a 0x14b 0x14c 0x14d 0x14e 0x14f BTN_GEAR_DOWN BTN_GEAR_UP 0x152 0x153 0x154 0x155 0x156 0x157 0x158 0x159 0x15a 0x15b 0x15c 0x15d 0x15e 0x15f OK SELECT GOTO CLEAR POWER2 OPTION INFO TIME VENDOR ARCHIVE 0x16a 0x16b 0x16c 0x16d 0x16e 0x16f LANGUAGE TITLE SUBTITLE ANGLE FULL_SCREEN MODE KEYBOARD ASPECT_RATIO PC TV 0x17a 0x17b 0x17c 0x17d 0x17e 0x17f TAPE RADIO TUNER PLAYER TEXT DVD AUX MP3 AUDIO VIDEO 0x18a 0x18b 0x18c 0x18d 0x18e 0x18f YELLOW BLUE CHANNELUP CHANNELDOWN FIRST LAST AB NEXT RESTART SLOW 0x19a 0x19b 0x19c 0x19d 0x19e 0x19f 0x1a0 0x1a1 0x1a2 0x1a3 0x1a4 0x1a5 0x1a6 0x1a7 0x1a8 0x1a9 0x1aa 0x1ab 0x1ac 0x1ad 0x1ae 0x1af 0x1b0 0x1b1 0x1b2 0x1b3 0x1b4 0x1b5 0x1b6 0x1b7 0x1b8 0x1b9 0x1ba 0x1bb 0x1bc 0x1bd 0x1be 0x1bf 0x1c0 0x1c1 0x1c2 0x1c3 0x1c4 0x1c5 0x1c6 0x1c7 0x1c8 0x1c9 0x1ca 0x1cb 0x1cc 0x1cd 0x1ce 0x1cf 0x1d0 0x1d1 0x1d2 0x1d3 0x1d4 0x1d5 0x1d6 0x1d7 0x1d8 0x1d9 0x1da 0x1db 0x1dc 0x1dd 0x1de 0x1df 0x1e0 0x1e1 0x1e2 0x1e3 0x1e4 0x1e5 0x1e6 0x1e7 0x1e8 0x1e9 0x1ea 0x1eb 0x1ec 0x1ed 0x1ee 0x1ef 0x1f0 0x1f1 0x1f2 0x1f3 0x1f4 0x1f5 0x1f6 0x1f7 0x1f8 0x1f9 0x1fa 0x1fb 0x1fc 0x1fd 0x1fe 0x1ff NUMERIC_0 NUMERIC_1 NUMERIC_2 NUMERIC_3 NUMERIC_4 NUMERIC_5 NUMERIC_6 NUMERIC_7 NUMERIC_8 NUMERIC_9 0x20a 0x20b 0x20c 0x20d 0x20e 0x20f CAMERA_FOCUS WPS_BUTTON TOUCHPAD_TOGGLE TOUCHPAD_ON TOUCHPAD_OFF CAMERA_ZOOMIN CAMERA_ZOOMOUT CAMERA_UP CAMERA_DOWN CAMERA_LEFT 0x21a 0x21b 0x21c 0x21d 0x21e 0x21f BTN_DPAD_UP BTN_DPAD_DOWN BTN_DPAD_LEFT BTN_DPAD_RIGHT 0x224 0x225 0x226 0x227 0x228 0x229 0x22a 0x22b 0x22c 0x22d 0x22e 0x22f ALS_TOGGLE ROTATE_LOCK_TOGGLE 0x232 0x233 0x234 0x235 0x236 0x237 0x238 0x239 0x23a 0x23b 0x23c 0x23d 0x23e 0x23f BUTTONCONFIG TASKMANAGER JOURNAL CONTROLPANEL APPSELECT SCREENSAVER VOICECOMMAND ASSISTANT 0x248 0x249 0x24a 0x24b 0x24c 0x24d 0x24e 0x24f BRIGHTNESS_MIN BRIGHTNESS_MAX 0x252 0x253 0x254 0x255 0x256 0x257 0x258 0x259 0x25a 0x25b 0x25c 0x25d 0x25e 0x25f KBDINPUTASSIST_PREV KBDINPUTASSIST_NEXT KBDINPUTASSIST_PREVGROUP KBDINPUTASSIST_NEXTGROUP KBDINPUTASSIST_ACCEPT KBDINPUTASSIST_CANCEL RIGHT_UP RIGHT_DOWN LEFT_UP LEFT_DOWN 0x26a 0x26b 0x26c 0x26d 0x26e 0x26f NEXT_FAVORITE STOP_RECORD PAUSE_RECORD VOD UNMUTE FASTREVERSE SLOWREVERSE DATA ONSCREEN_KEYBOARD"
EV_REL="X Y Z RX RY RZ HWHEEL DIAL WHEEL MISC"
EV_ABS="X Y Z RX RY RZ THROTTLE RUDDER WHEEL GAS 0xa 0xb 0xc 0xd 0xe 0xf HAT0X HAT0Y HAT1X HAT1Y HAT2X HAT2Y HAT3X HAT3Y PRESSURE DISTANCE 0x1a 0x1b 0x1c 0x1d 0x1e 0x1f VOLUME 0x21 0x22 0x23 0x24 0x25 0x26 0x27 MISC 0x29 0x2a 0x2b 0x2c 0x2d 0x2e 0x2f MT_TOUCH_MAJOR MT_TOUCH_MINOR MT_WIDTH_MAJOR MT_WIDTH_MINOR MT_ORIENTATION MT_POSITION_X MT_POSITION_Y MT_TOOL_TYPE MT_BLOB_ID MT_TRACKING_ID"
EV_MSC="SERIAL PULSELED GESTURE RAW SCAN TIMESTAMP 0x6 MAX"
EV_SW="LID TABLET_MODE HEADPHONE_INSERT RFKILL_ALL MICROPHONE_INSERT DOCK LINEOUT_INSERT JACK_PHYSICAL_INSERT VIDEOOUT_INSERT CAMERA_LENS_COVER"
EV_LED="NUML CAPSL SCROLLL COMPOSE KANA SLEEP SUSPEND MUTE MISC MAIL"
EV_SND="CLICK BELL TONE 0x3 0x4 0x5 0x6 MAX"
EV_REP="DELAY MAX"

# convert event string to number
input_event_str2int() {
    local type="$1"
    local code="$2"

    case $type in
        SYN) set -- $EV_SYN ;;
        KEY) set -- $EV_KEY ;;
        REL) set -- $EV_REL ;;
        ABS) set -- $EV_ABS ;;
        MSC) set -- $EV_MSC ;;
        SW)  set -- $EV_SW  ;;
        LED) set -- $EV_LED ;;
        SND) set -- $EV_SND ;;
        REP) set -- $EV_REP ;;
        *)   set --         ;;
    esac

    code=$(printf " %s \n" $@  | grep -n -F " $code ")
    [ $? -eq 0 ] && code=$((${code%%:*}-1))
    type=$(printf " %s \n" $EV | grep -n -F " $type ")
    [ $? -eq 0 ] && type=$((${type%%:*}-1))

    echo $type $code
}

# convert event number to string
input_event_int2str() {
    local type="$1"
    local code="$2"

    set -- $EV
    [ $# -gt $type ] && shift $type || set --
    type=${1:-$type}

    case $type in
        SYN) set -- $EV_SYN ;;
        KEY) set -- $EV_KEY ;;
        REL) set -- $EV_REL ;;
        ABS) set -- $EV_ABS ;;
        MSC) set -- $EV_MSC ;;
        SW)  set -- $EV_SW  ;;
        LED) set -- $EV_LED ;;
        SND) set -- $EV_SND ;;
        REP) set -- $EV_REP ;;
        *)   set --         ;;
    esac

    [ $# -gt $code ] && shift $code || set --
    code=${1:-$code}

    echo $type $code
}

check_event() {
    [ "$cfg_debug" = 1 ] && debug_event "$@"

    while [ $# -ge 5 ]
    do
        for item in $cfg_whitelist
        do
            if [ "$item" = "$3:$4" ]
            then
                # successful
                [ "$cfg_causality" = 1 ] && causality="$(input_event_int2str $3 $4 | tr ' ' ':') $5"
                return 0
            fi
        done
        shift 5
    done

    # unsuccessful
    return 1
}

debug_event() {
    eventstr="MiniClock debug event:"

    while [ $# -ge 5 ]
    do
        eventstr="$eventstr"$'\n'"[$1 $(input_event_int2str $3 $4 | tr ' ' ':') $5]"
        shift 5
    done

    sleep 3
    fbink -x 2 -y 2 "$eventstr"
}

# --- Main: ---

main() {
    local i=0
    local x=0
    local negative=0

    udev_workarounds
    wait_for_nickel

    while sleep 1
    do
        load_config
        nightmode_check

        if check_event $(devinputeventdump /dev/input/event1 /dev/input/event0)
        then
           # event coming in hot
           for i in $cfg_delay
           do
               sleep $i
               update
           done
           negative=0
        else
           # unknown event, cold
           negative=$(($negative+1))

           # getting cold events in a row? sleep a while.
           if [ "$negative" -ge "${cfg_cooldown% *}" ]
           then
               if [ "$cfg_causality" = 1 ]
               then
                   # update only to display cooldown {debug}
                   causality="cooldown $cfg_cooldown"
                   for i in $cfg_delay
                   do
                       sleep $i
                       update
                   done
               fi

               sleep "${cfg_cooldown#* }"
               negative=0
           fi
        fi
    done
}

main
