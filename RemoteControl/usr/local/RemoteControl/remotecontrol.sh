#!/bin/sh

export PATH="/usr/local/RemoteControl:$PATH"
export LD_LIBRARY_PATH="/usr/local/RemoteControl:$LD_LIBRARY_PATH"

base="/mnt/onboard/.addons/remotecontrol"
configfile="$base/remotecontrol.cfg"
tmpdir="/tmp/RemoteControl"

wait_for_base() {
    while [ ! -e "$base" ]
    do
        sleep 5
    done
}

# uninstall
uninstall_check() {
    if [ "$(config uninstall 0)" = "1" ]
    then
        mv "$configfile" "$base"/uninstalled-$(date +%Y%m%d-%H%M).cfg
        rm -rf /usr/local/"RemoteControl"
        rm -rf "$tmpdir"
        exit
    fi
}

# config parser
config() {
    local value
    value=$(grep -E -m 1 "^$1\s*=" "$configfile" | tr -d '\r')
    value="${value:${#1}}"
    value="${value#*=}"
    shift
    [ "$value" != "" ] && echo "$value" || echo "$@"
}

# config loader
load_config() {
    [ -z "${config_loaded:-}" ] || grep /mnt/onboard /proc/mounts || return 1 # not mounted
    [ -z "${config_loaded:-}" ] || [ "$configfile" -nt /tmp/"RemoteControl" -o "$configfile" -ot /tmp/"RemoteControl" ] || return 1 # not changed

    config_loaded=1
    touch -r "$configfile" /tmp/"RemoteControl" # remember timestamp

    uninstall_check

    cfg_touchscreen=$(config touchscreen '/dev/input/event1')
    cfg_timeout=$(config timeout '10')
    cfg_total=$(config timeout '60')
    cfg_limit=$(config limit '1000')
}

# --- Record & Replay: ---

# uptime, origin (first call uptime), offset (time since origin), delta (time since previous call)
deltatime() {
    read uptime idle < /proc/uptime
    uptime=${uptime/./}
    origin=${origin:-$uptime}
    offset=$(($uptime-$origin))
    delta=$(($uptime-${1:-$uptime}))
}

record() {
    local name="$1"

    (
        origin=
        uptime=

        for i in $(seq -w "$cfg_limit")
        do
            # grab next chunk
            dd bs=64K count=1 of="${tmpdir}/dd"

            # calculate time
            deltatime $uptime

            # break if timeout passed since last chunk
            [ "$delta" -gt "$cfg_timeout"00 ] && break
            [ "$offset" -gt "$cfg_total"00 ] && break

            # otherwise timestamp chunk
            mv "${tmpdir}/dd" "${tmpdir}/${i}-${offset}-${delta}.raw"
        done
    ) < "$cfg_touchscreen"
}

replay() {
   for f in "$tmpdir"/*.raw
   do
       delta=$f
       delta=${delta##*-}
       delta=${delta%.raw}

       # sleep if it looks like expected...
       case "$delta" in
           [0-9])
               ;; # sleep "0.0${delta:0:1}" ;; # not much point...
           [0-9][0-9])
               sleep "0.${delta:0:2}"  ;;
           [0-9][0-9][0-9])
               sleep "${delta:0:1}.${delta:1:2}"  ;;
           [0-9][0-9][0-9][0-9])
               sleep "${delta:0:2}.${delta:2:2}"  ;;
       esac

       cat "$f" > "$cfg_touchscreen"
   done
}

# --- Main: ---

main() {
    mkdir -p "$tmpdir"
    wait_for_base
    load_config
}

# main
