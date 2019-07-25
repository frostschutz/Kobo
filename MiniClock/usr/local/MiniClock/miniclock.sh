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

    # debug handling
    case "$cfg_format $cfg_truetype_format" in
        *{debug}*) cfg_causality=1 ;;
        *)         cfg_causality=0 ;;
    esac

    do_debug_log() {
        echo "$@" >> /mnt/onboard/.addons/miniclock/debuglog.txt
    }

    if [ "$cfg_debug" = "1" ]
    then
        debug_log() {
            return 0 # yes
        }
    else
        debug_log() {
            return 1 # no
        }
    fi

    debug_log && do_debug_log "-- config file read $(date) --"
    debug_log && do_debug_log "-- cfg_debug = '$cfg_debug', format {debug} = '$cfg_causality' --"

    # patch handling
    if [ ! -e /tmp/MiniClock/patch -a "$cfg_button" == "1" ]
    then
        touch /tmp/MiniClock/patch

        libnickel=$(realpath /usr/local/Kobo/libnickel.so)
        if strings "$libnickel" | grep -F '/dev/input/event0:keymap=keys/device.qmap:grab=1'
        then
            sed -i -e 's@/dev/input/event0:keymap=keys/device.qmap:grab=1@/dev/input/event0:keymap=keys/device.qmap:grab=0@' "$libnickel"
            touch /tmp/MiniClock/reboot
            debug_log && do_debug_log "-- patched libnickel, require reboot --"
        fi
    fi

    # whitelist filtering (string to number)
    debug_log && do_debug_log "-- cfg_whitelist = '$cfg_whitelist' --"
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
    debug_log && do_debug_log "-- cfg_whitelist (str2int) = '$cfg_whitelist' --"
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

    debug_log && do_debug_log "-- clock update $(date) --"

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

EV="SYN KEY REL ABS MSC SW 0x6 0x7 0x8 0x9 0xa 0xb 0xc 0xd 0xe 0xf 0x10 LED SND 0x13 REP FF PWR FF_STATUS 0x18 0x19 0x1a 0x1b 0x1c 0x1d 0x1e MAX"
EV_SYN="REPORT CONFIG MT_REPORT DROPPED 0x4 0x5 0x6 0x7 0x8 0x9 0xa 0xb 0xc 0xd 0xe MAX"
EV_KEY="RESERVED ESC 1 2 3 4 5 6 7 8 9 0 MINUS EQUAL BACKSPACE TAB Q W E R T Y U I O P LEFTBRACE RIGHTBRACE ENTER LEFTCTRL A S D F G H J K L SEMICOLON APOSTROPHE GRAVE LEFTSHIFT BACKSLASH Z X C V B N M COMMA DOT SLASH RIGHTSHIFT KPASTERISK LEFTALT SPACE CAPSLOCK F1 F2 F3 F4 F5 F6 F7 F8 F9 F10 NUMLOCK SCROLLLOCK KP7 KP8 KP9 KPMINUS KP4 KP5 KP6 KPPLUS KP1 KP2 KP3 KP0 KPDOT 0x54 ZENKAKUHANKAKU 102ND F11 F12 RO KATAKANA HIRAGANA HENKAN KATAKANAHIRAGANA MUHENKAN KPJPCOMMA KPENTER RIGHTCTRL KPSLASH SYSRQ RIGHTALT LINEFEED HOME UP PAGEUP LEFT RIGHT END DOWN PAGEDOWN INSERT DELETE MACRO MUTE VOLUMEDOWN VOLUMEUP POWER KPEQUAL KPPLUSMINUS PAUSE SCALE KPCOMMA HANGEUL HANJA YEN LEFTMETA RIGHTMETA COMPOSE STOP AGAIN PROPS UNDO FRONT COPY OPEN PASTE FIND CUT HELP MENU CALC SETUP SLEEP WAKEUP FILE SENDFILE DELETEFILE XFER PROG1 PROG2 WWW MSDOS COFFEE ROTATE_DISPLAY CYCLEWINDOWS MAIL BOOKMARKS COMPUTER BACK FORWARD CLOSECD EJECTCD EJECTCLOSECD NEXTSONG PLAYPAUSE PREVIOUSSONG STOPCD RECORD REWIND PHONE ISO CONFIG HOMEPAGE REFRESH EXIT MOVE EDIT SCROLLUP SCROLLDOWN KPLEFTPAREN KPRIGHTPAREN NEW REDO F13 F14 F15 F16 F17 F18 F19 F20 F21 F22 F23 F24 0xc3 0xc4 0xc5 0xc6 0xc7 PLAYCD PAUSECD PROG3 PROG4 DASHBOARD SUSPEND CLOSE PLAY FASTFORWARD BASSBOOST PRINT HP CAMERA SOUND QUESTION EMAIL CHAT SEARCH CONNECT FINANCE SPORT SHOP ALTERASE CANCEL BRIGHTNESSDOWN BRIGHTNESSUP MEDIA SWITCHVIDEOMODE KBDILLUMTOGGLE KBDILLUMDOWN KBDILLUMUP SEND REPLY FORWARDMAIL SAVE DOCUMENTS BATTERY BLUETOOTH WLAN UWB UNKNOWN VIDEO_NEXT VIDEO_PREV BRIGHTNESS_CYCLE BRIGHTNESS_AUTO DISPLAY_OFF WWAN RFKILL MICMUTE 0xf9 0xfa 0xfb 0xfc 0xfd 0xfe 0xff BTN_0 BTN_1 BTN_2 BTN_3 BTN_4 BTN_5 BTN_6 BTN_7 BTN_8 BTN_9 0x10a 0x10b 0x10c 0x10d 0x10e 0x10f BTN_LEFT BTN_RIGHT BTN_MIDDLE BTN_SIDE BTN_EXTRA BTN_FORWARD BTN_BACK BTN_TASK 0x118 0x119 0x11a 0x11b 0x11c 0x11d 0x11e 0x11f BTN_TRIGGER BTN_THUMB BTN_THUMB2 BTN_TOP BTN_TOP2 BTN_PINKIE BTN_BASE BTN_BASE2 BTN_BASE3 BTN_BASE4 BTN_BASE5 BTN_BASE6 0x12c 0x12d 0x12e BTN_DEAD BTN_SOUTH BTN_EAST BTN_C BTN_NORTH BTN_WEST BTN_Z BTN_TL BTN_TR BTN_TL2 BTN_TR2 BTN_SELECT BTN_START BTN_MODE BTN_THUMBL BTN_THUMBR 0x13f BTN_TOOL_PEN BTN_TOOL_RUBBER BTN_TOOL_BRUSH BTN_TOOL_PENCIL BTN_TOOL_AIRBRUSH BTN_TOOL_FINGER BTN_TOOL_MOUSE BTN_TOOL_LENS BTN_TOOL_QUINTTAP BTN_STYLUS3 BTN_TOUCH BTN_STYLUS BTN_STYLUS2 BTN_TOOL_DOUBLETAP BTN_TOOL_TRIPLETAP BTN_TOOL_QUADTAP BTN_GEAR_DOWN BTN_GEAR_UP 0x152 0x153 0x154 0x155 0x156 0x157 0x158 0x159 0x15a 0x15b 0x15c 0x15d 0x15e 0x15f OK SELECT GOTO CLEAR POWER2 OPTION INFO TIME VENDOR ARCHIVE PROGRAM CHANNEL FAVORITES EPG PVR MHP LANGUAGE TITLE SUBTITLE ANGLE FULL_SCREEN MODE KEYBOARD ASPECT_RATIO PC TV TV2 VCR VCR2 SAT SAT2 CD TAPE RADIO TUNER PLAYER TEXT DVD AUX MP3 AUDIO VIDEO DIRECTORY LIST MEMO CALENDAR RED GREEN YELLOW BLUE CHANNELUP CHANNELDOWN FIRST LAST AB NEXT RESTART SLOW SHUFFLE BREAK PREVIOUS DIGITS TEEN TWEN VIDEOPHONE GAMES ZOOMIN ZOOMOUT ZOOMRESET WORDPROCESSOR EDITOR SPREADSHEET GRAPHICSEDITOR PRESENTATION DATABASE NEWS VOICEMAIL ADDRESSBOOK MESSENGER DISPLAYTOGGLE SPELLCHECK LOGOFF DOLLAR EURO FRAMEBACK FRAMEFORWARD CONTEXT_MENU MEDIA_REPEAT 10CHANNELSUP 10CHANNELSDOWN IMAGES 0x1bb 0x1bc 0x1bd 0x1be 0x1bf DEL_EOL DEL_EOS INS_LINE DEL_LINE 0x1c4 0x1c5 0x1c6 0x1c7 0x1c8 0x1c9 0x1ca 0x1cb 0x1cc 0x1cd 0x1ce 0x1cf FN FN_ESC FN_F1 FN_F2 FN_F3 FN_F4 FN_F5 FN_F6 FN_F7 FN_F8 FN_F9 FN_F10 FN_F11 FN_F12 FN_1 FN_2 FN_D FN_E FN_F FN_S FN_B 0x1e5 0x1e6 0x1e7 0x1e8 0x1e9 0x1ea 0x1eb 0x1ec 0x1ed 0x1ee 0x1ef 0x1f0 BRL_DOT1 BRL_DOT2 BRL_DOT3 BRL_DOT4 BRL_DOT5 BRL_DOT6 BRL_DOT7 BRL_DOT8 BRL_DOT9 BRL_DOT10 0x1fb 0x1fc 0x1fd 0x1fe 0x1ff NUMERIC_0 NUMERIC_1 NUMERIC_2 NUMERIC_3 NUMERIC_4 NUMERIC_5 NUMERIC_6 NUMERIC_7 NUMERIC_8 NUMERIC_9 NUMERIC_STAR NUMERIC_POUND NUMERIC_A NUMERIC_B NUMERIC_C NUMERIC_D CAMERA_FOCUS WPS_BUTTON TOUCHPAD_TOGGLE TOUCHPAD_ON TOUCHPAD_OFF CAMERA_ZOOMIN CAMERA_ZOOMOUT CAMERA_UP CAMERA_DOWN CAMERA_LEFT CAMERA_RIGHT ATTENDANT_ON ATTENDANT_OFF ATTENDANT_TOGGLE LIGHTS_TOGGLE 0x21f BTN_DPAD_UP BTN_DPAD_DOWN BTN_DPAD_LEFT BTN_DPAD_RIGHT 0x224 0x225 0x226 0x227 0x228 0x229 0x22a 0x22b 0x22c 0x22d 0x22e 0x22f ALS_TOGGLE ROTATE_LOCK_TOGGLE 0x232 0x233 0x234 0x235 0x236 0x237 0x238 0x239 0x23a 0x23b 0x23c 0x23d 0x23e 0x23f BUTTONCONFIG TASKMANAGER JOURNAL CONTROLPANEL APPSELECT SCREENSAVER VOICECOMMAND ASSISTANT 0x248 0x249 0x24a 0x24b 0x24c 0x24d 0x24e 0x24f BRIGHTNESS_MIN BRIGHTNESS_MAX 0x252 0x253 0x254 0x255 0x256 0x257 0x258 0x259 0x25a 0x25b 0x25c 0x25d 0x25e 0x25f KBDINPUTASSIST_PREV KBDINPUTASSIST_NEXT KBDINPUTASSIST_PREVGROUP KBDINPUTASSIST_NEXTGROUP KBDINPUTASSIST_ACCEPT KBDINPUTASSIST_CANCEL RIGHT_UP RIGHT_DOWN LEFT_UP LEFT_DOWN ROOT_MENU MEDIA_TOP_MENU NUMERIC_11 NUMERIC_12 AUDIO_DESC 3D_MODE NEXT_FAVORITE STOP_RECORD PAUSE_RECORD VOD UNMUTE FASTREVERSE SLOWREVERSE DATA ONSCREEN_KEYBOARD 0x279 0x27a 0x27b 0x27c 0x27d 0x27e 0x27f 0x280 0x281 0x282 0x283 0x284 0x285 0x286 0x287 0x288 0x289 0x28a 0x28b 0x28c 0x28d 0x28e 0x28f 0x290 0x291 0x292 0x293 0x294 0x295 0x296 0x297 0x298 0x299 0x29a 0x29b 0x29c 0x29d 0x29e 0x29f 0x2a0 0x2a1 0x2a2 0x2a3 0x2a4 0x2a5 0x2a6 0x2a7 0x2a8 0x2a9 0x2aa 0x2ab 0x2ac 0x2ad 0x2ae 0x2af 0x2b0 0x2b1 0x2b2 0x2b3 0x2b4 0x2b5 0x2b6 0x2b7 0x2b8 0x2b9 0x2ba 0x2bb 0x2bc 0x2bd 0x2be 0x2bf BTN_TRIGGER_HAPPY1 BTN_TRIGGER_HAPPY2 BTN_TRIGGER_HAPPY3 BTN_TRIGGER_HAPPY4 BTN_TRIGGER_HAPPY5 BTN_TRIGGER_HAPPY6 BTN_TRIGGER_HAPPY7 BTN_TRIGGER_HAPPY8 BTN_TRIGGER_HAPPY9 BTN_TRIGGER_HAPPY10 BTN_TRIGGER_HAPPY11 BTN_TRIGGER_HAPPY12 BTN_TRIGGER_HAPPY13 BTN_TRIGGER_HAPPY14 BTN_TRIGGER_HAPPY15 BTN_TRIGGER_HAPPY16 BTN_TRIGGER_HAPPY17 BTN_TRIGGER_HAPPY18 BTN_TRIGGER_HAPPY19 BTN_TRIGGER_HAPPY20 BTN_TRIGGER_HAPPY21 BTN_TRIGGER_HAPPY22 BTN_TRIGGER_HAPPY23 BTN_TRIGGER_HAPPY24 BTN_TRIGGER_HAPPY25 BTN_TRIGGER_HAPPY26 BTN_TRIGGER_HAPPY27 BTN_TRIGGER_HAPPY28 BTN_TRIGGER_HAPPY29 BTN_TRIGGER_HAPPY30 BTN_TRIGGER_HAPPY31 BTN_TRIGGER_HAPPY32 BTN_TRIGGER_HAPPY33 BTN_TRIGGER_HAPPY34 BTN_TRIGGER_HAPPY35 BTN_TRIGGER_HAPPY36 BTN_TRIGGER_HAPPY37 BTN_TRIGGER_HAPPY38 BTN_TRIGGER_HAPPY39 BTN_TRIGGER_HAPPY40 0x2e8 0x2e9 0x2ea 0x2eb 0x2ec 0x2ed 0x2ee 0x2ef 0x2f0 0x2f1 0x2f2 0x2f3 0x2f4 0x2f5 0x2f6 0x2f7 0x2f8 0x2f9 0x2fa 0x2fb 0x2fc 0x2fd 0x2fe MAX"
EV_REL="X Y Z RX RY RZ HWHEEL DIAL WHEEL MISC RESERVED WHEEL_HI_RES HWHEEL_HI_RES 0xd 0xe MAX"
EV_ABS="X Y Z RX RY RZ THROTTLE RUDDER WHEEL GAS BRAKE 0xb 0xc 0xd 0xe 0xf HAT0X HAT0Y HAT1X HAT1Y HAT2X HAT2Y HAT3X HAT3Y PRESSURE DISTANCE TILT_X TILT_Y TOOL_WIDTH 0x1d 0x1e 0x1f VOLUME 0x21 0x22 0x23 0x24 0x25 0x26 0x27 MISC 0x29 0x2a 0x2b 0x2c 0x2d RESERVED MT_SLOT MT_TOUCH_MAJOR MT_TOUCH_MINOR MT_WIDTH_MAJOR MT_WIDTH_MINOR MT_ORIENTATION MT_POSITION_X MT_POSITION_Y MT_TOOL_TYPE MT_BLOB_ID MT_TRACKING_ID MT_PRESSURE MT_DISTANCE MT_TOOL_X MT_TOOL_Y 0x3e MAX"
EV_MSC="SERIAL PULSELED GESTURE RAW SCAN TIMESTAMP 0x6 MAX"
EV_SW="LID TABLET_MODE HEADPHONE_INSERT RFKILL_ALL MICROPHONE_INSERT DOCK LINEOUT_INSERT JACK_PHYSICAL_INSERT VIDEOOUT_INSERT CAMERA_LENS_COVER KEYPAD_SLIDE FRONT_PROXIMITY ROTATE_LOCK LINEIN_INSERT MUTE_DEVICE MAX"
EV_LED="NUML CAPSL SCROLLL COMPOSE KANA SLEEP SUSPEND MUTE MISC MAIL CHARGING 0xb 0xc 0xd 0xe MAX"
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
                [ "$cfg_causality" = 1 ] && causality="$(input_event_int2str $3 $4 | tr ' ' ':') $5" &&
                    debug_log && do_debug_log "-- whitelist match -- $causality" ||
                    debug_log && do_debug_log "-- whitelist match -- $(input_devent_int2str $3 $4 | tr ' ' ':')"
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

    debug_log && do_debug_log "$eventstr"
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
           debug_log && do_debug_log "-- cfg_delay = '$cfg_delay' --"
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

           debug_log && do_debug_log "-- whitelist not matched - negative $negative --"

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

               debug_log && do_debug_log "-- cooldown start, $(date) --"
               sleep "${cfg_cooldown#* }"
               negative=0
               debug_log && do_debug_log "-- cooldown end,   $(date) --"
           fi
        fi
    done
}

main
