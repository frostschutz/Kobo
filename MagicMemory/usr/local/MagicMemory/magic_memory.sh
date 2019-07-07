#!/bin/sh

# Magic Memory Upgrade Mod for Kobo ebook readers
# version 2019-05-27 by frostschutz
#
# Upgrades or Replaces or Clones the Kobo's internal SD card.
# Copy data from old SD card to RAM, switch cards.
# Copy data from RAM to new SD card, switch cards.
# Repeat until all files are transferred over.
#
# Thanks to:
# * https://github.com/NiLuJe/FBInk ( display all the things )
# * https://github.com/FortAwesome/Font-Awesome ( free icons )

# --- Helpers: ---

# convert bytes to human readable unit (rounded up)
h_unit() {
    local value=$1
    local unit="b"
    set -- K M G T

    while [ $value -ge 900 -a $# -ge 1 ]
    do
        value=$(( ($value+400) / 1000 ))
        unit=$1
        shift
    done

    echo "$value$unit"
}

# expect X seconds for touch
# return 0 if touched
# return 1 if not touched
timeout_touch() {
    local touched="not"
    read -t "$1" touched < /dev/input/event1
    [ "$touched" != "not" ]
}

# --- FBInk Helpers: ---

# grab fbink variables: {view,screen}{Width,Height}, DPI, BPP, device{Name,Id,Codename,Platform}, ...
fbink_eval() {
    eval $(fbink --quiet --eval; echo "exit=$?")
    vviewWidth=$viewWidth
    vviewHeight=$viewHeight
    # # virtual resolution for testing only
    # vviewWidth=768
    # vviewHeight=1024
}

# draw something and grab its coordinates lastRect_{Top,Left,Width,Height}
fbink_coordinates() {
    eval $(fbink --quiet --coordinates --norefresh "$@" 2> /dev/null; echo "exit=$?;")
}

# draw truetype text and grab rendered_lines, truncated, ...
fbink_truetype() {
    eval $(fbink --quiet --linecount --norefresh --truetype "$@" 2> /dev/null; echo "exit=$?;")
}

# refresh whole screen
fbink_refresh() {
    fbink --quiet --refresh '' "$@"
}

# refresh whole screen (with inversion flash)
fbink_flash() {
    fbink --quiet --flash --refresh '' "$@"
}

# show an error message
fbink_error() {
    fbink_dirty=1
    fbink --clear
    fbink "$@"
    sleep 60
}

# render text to a given rectangle ( on a virtual 600x800 screen )
# optimal pointsize determined automatically ( not 100% reliable )
# dirties the framebuffer so requires a re-draw pass
fbink_dirty=0
point_cache=""
fbink_render_text() {
    local rect="$1" # x y width height
    local font="$2"
    local text="$3"
    shift 3
    local extra_args="$@"

    if [ -z "text" ]
    then
        fbink_error "empty text" "$font @ $rect"
        return
    fi

    # translate coordinates
    set -- $rect
    local left=$(($1 * $vviewWidth / 600))
    local top=$(($2 * $vviewHeight / 800))
    local width=$(($3 * $vviewWidth / 600))
    local height=$(($4 * $vviewHeight / 800))
    local right=$(($viewWidth - $left - $width))
    local bottom=$(($viewHeight - $top - $height))

    # echo "$rect = [ $left $top $width $height $right $bottom ]"

    # grab pointsize from cache
    local key=$(printf "%s\0" "$font" "$text" "$width" "$height" "$extra_args" | md5sum | head -c 8)
    local point=${point_cache#*$key=}
    point=${point%% *}

    # or re-detect pointsize (dirty)
    if [ -z $point ]
    then
        fbink_dirty=1

        local min=10
        local max=20
        local steps=0
        local upper=0
        local lower=0

        while [ $steps -lt 20 -a $min -lt $max ]
        do
            steps=$(($steps+1))
            point=$(( ($min+$max+1) / 2 ))
            truncated=1
            exit=1

            fbink_truetype \
              "regular=$font,size=$point,left=$left,top=$top,right=$right,bottom=$bottom" \
              $extra_args \
              -- "$text"

            if [ "$exit" != "0" -o "$truncated" != "0" ]
            then
                # too large
                max=$(($point-1))
                upper=1
                [ "$lower" == 0 ] && min=$(( ($min+1) / 2 ))
            else
                # too small?
                min=$point
                lower=1
                [ "$upper" == 0 ] && max=$(($max*2))
            fi
        done

        point=$min
        point_cache="$point_cache $key=$point "

        echo $point "$text"
    fi

    # actually draw it out
    fbink --quiet --norefresh $extra_args \
          --truetype "regular=$font,size=$point,left=$left,top=$top,right=$right,bottom=$bottom" \
          -- "$text" ||
    fbink_error "render error $?" "$font ($point) @ $rect"
}

# render centered text
fbink_render_cntr() {
    fbink_render_text "$@" --halfway --centered
}

# render overlay text
fbink_render_over() {
    fbink_render_cntr "$@" --overlay
}

# --- UI: ---

# display battery status
d_battery() {
    local capacity=$(cat /sys/devices/platform/pmic_battery.1/power_supply/*/capacity)
    local status=$(cat /sys/devices/platform/pmic_battery.1/power_supply/*/status)
    local icon=""
    local info=""

    echo BATTERY "$capacity" "$status"

    case "$capacity" in
      100|9[0-9])  icon=$'\xef\x89\x80'  ;; # U+F240 fa-battery-full
      [7-8][0-9])  icon=$'\xef\x89\x81'  ;; # U+F241 fa-battery-three-quarters
      [5-6][0-9])  icon=$'\xef\x89\x82'  ;; # U+F242 fa-battery-half
      [2-4][0-9])  icon=$'\xef\x89\x83'  ;; # U+F243 fa-battery-quarter
      1[0-9])      icon=$'\xef\x89\x84'  ;; # U+F244 fa-battery-empty
      [0-9])       icon=$'\xef\x89\x84'     # U+F244 fa-battery-empty
                   info=$'\xef\x9c\x94'  ;; # U+F714 fa-skull-crossbones
      *)           icon=$'\xef\x94\xbe'  ;; # U+F53E fa-not-equal
    esac

    case "$status" in
      Discharging)  ;;
      Charging)     info=$'\xef\x83\xa7'  ;; # U+F0E7 fa-bolt
      Not?charging) info=$'\xef\x87\xa6'  ;; # U+F1E6 fa-plug
      Full)         info=$'\xef\x97\xa7'  ;; # U+F5E7 fa-charging-station
      *)            info=$'\xef\x8b\xbe'  ;; # U+F2FE fa-poo
    esac

    fbink_render_text "500 50 50 50" fa.ttf "$info$icon"
}

# display logo
d_logo() {
    fbink_render_text "50 50 50 50" fa.ttf $'\xef\x9b\xa8' # U+F6E8 fa-hat-wizard
}

# display title
d_title() {
    fbink_render_cntr "150 50 300 50" vera.ttf "Magic Memory"
}

# display ram
d_ram() {
    set -- $(grep -E '^(MemTotal|MemFree|Buffers|Cached|Shmem):' /proc/meminfo) \
           MemTotal: 0 kB MemFree: 0 kB Buffers: 0 kB Cached: 0 kB Shmem: 0 kB

    local memtotal=$(($2*1024))
    local memfree=$(($5*1024+$8*1024+$11*1024-$14*1024)) # free+buffers+cached-shmem
    local memused=$(($memtotal-$memfree))

    fbink_render_cntr "75 150 50 50" fa.ttf $'\xef\x8b\x9b' # U+F538 fa-microchip
    fbink_render_over "85 140 30 70" vera.ttf "RAM"
    fbink_render_cntr "50 250 100 25" vera.ttf "Total:"
    fbink_render_cntr "50 325 100 25" vera.ttf "Used:"
    fbink_render_cntr "50 400 100 25" vera.ttf "Free:"
    fbink_render_cntr "50 275 100 50" vera.ttf $(h_unit "$memtotal")
    fbink_render_cntr "50 350 100 50" vera.ttf $(h_unit "$memused")
    fbink_render_cntr "50 425 100 50" vera.ttf $(h_unit "$memfree")
}

# display internal sd card
d_sd_int() {
    set -- $(cat /sys/block/mmcblk0/size) 0
    local size=$(($1*512))

    fbink_render_cntr "200 150 50 50" fa.ttf $'\xef\x9f\x82' # U+F7C2 fa-sd-card
    fbink_render_over "210 170 30 30" vera.ttf "INT"

    if [ $size -le 0 ]
    then
        # there is no internal sd card present
        fbink_render_over "200 150 50 50" fa.ttf $'\xef\x9c\x95' # U+F715 fa-slash
        fbink_render_cntr "250 150 50 50" fa.ttf $'\xef\x81\xa5' # U+F065 fa-expand
    else
        fbink_render_cntr "250 150 100 50" vera.ttf $(h_unit "$size")
        d_int_partitions
    fi
}

d_int_partitions() {
    # show partitions
    local pstart=0
    local psize=0
    local pmin=0
    local pmax=0
    local pfree=0
    local pother=0

    for partition in /sys/block/mmcblk0/mmcblk0p*
    do
        [ ! -e "$partition" ] && continue

        pstart=$(( $(cat "$partition"/start) * 512 ))
        psize=$(( $(cat "$partition"/size) * 512 ))

        [ $pmin -eq 0 -o $pmin -gt $pstart ] && pmin=$pstart
        [ $pmax -lt $(($pstart+$psize)) ] && pmax=$(($pstart+$psize))

        case "$partition" in
          *p1) # rootfs
            fbink_render_cntr "200 300 50 50" fa.ttf $'\xef\x84\xa1' # U+F121 fa-code
            fbink_render_cntr "250 300 100 50" vera.ttf $(h_unit "$psize")
            ;;
          *p2) # recoveryfs
            fbink_render_cntr "200 350 50 50" fa.ttf $'\xef\x93\x8d' # U+F4CD fa-parachute-box
            fbink_render_cntr "250 350 100 50" vera.ttf $(h_unit "$psize")
            ;;
          *p3) # KOBOeReader
            fbink_render_cntr "200 400 50 50" fa.ttf $'\xef\x80\xad' # U+F02D fa-book
            fbink_render_cntr "250 400 100 50" vera.ttf $(h_unit "$psize")
            ;;
          *) # other?!
            fbink_render_cntr "200 500 50 50" fa.ttf $'\xef\x81\x99' # U+F059 fa-question-circle
            pother=$(($pother+$psize))
            fbink_render_over "250 500 100 50" vera.ttf $(h_unit "$pother")
            ;;
        esac
    done

    # kernel
    if [ $pmin -gt 0 ]
    then
        fbink_render_cntr "200 250 50 50" fa.ttf $'\xef\x95\x84' # U+F544 fa-robot
        fbink_render_cntr "250 250 100 50" vera.ttf $(h_unit $pmin)
    fi

    # free space
    pfree=$(( $(cat /sys/block/mmcblk0/size)*512 - $pmax ))
    if [ $pfree -gt 0 ]
    then
        fbink_render_cntr "200 450 50 50" fa.ttf $'\xef\x87\x8e' # U+F1CE fa-circle-notch
        fbink_render_over "208 458 34 34" vera.ttf "FREE"
        fbink_render_cntr "250 450 100 50" vera.ttf $(h_unit $pfree)
    fi
}

# display external sd card
d_sd_ext() {
    # external sdcard:
    set -- $(cat /sys/block/mmcblk1/size) 0
    local extsize=$(($1*512))

    fbink_render_cntr "400 150 50 50" fa.ttf $'\xef\x9f\x82' # U+F7C2 fa-sd-card
    fbink_render_over "410 170 30 30" vera.ttf "EXT"

    if [ $extsize -gt 0 ]
    then
        fbink_render_cntr "450 150 100 50" vera.ttf $(h_unit "$extsize")
        d_ext_partitions
    else
        fbink_render_over "400 150 100 50" fa.ttf $'\xef\x9c\x95' # U+F715 fa-slash
        fbink_render_cntr "450 150 100 50" fa.ttf $'\xef\x81\xa5' # U+F065 fa-expand
    fi
}

d_ext_partitions() {
    # show partitions
    local psize=0
    local pmax=0
    local pfree=0
    local pother=0

    for partition in /sys/block/mmcblk1/mmcblk1p*
    do
        [ ! -e "$partition" ] && continue

        psize=$(( $(cat "$partition"/size) * 512 ))

        [ $pmax -lt $(($pstart+$psize)) ] && pmax=$(($pstart+$psize))

        case "$partition" in
          *p1) # user vfat
            fbink_render_cntr "400 250 50 50" fa.ttf $'\xef\x9f\xa6' # U+F7E6 fa-book-medical
            fbink_render_cntr "450 250 100 50" vera.ttf $(h_unit "$psize")
            ;;
          *) # other?!
            fbink_render_cntr "400 300 50 50" fa.ttf $'\xef\x81\x99' # U+F059 fa-question-circle
            pother=$(($pother+$psize))
            fbink_render_cntr "450 300 100 50" vera.ttf $(h_unit "$pother")
            ;;
        esac
    done

    # free space
    pfree=$(( $(cat /sys/block/mmcblk1/size)*512 - $pmax ))
    if [ $pfree -gt 0 ]
    then
        fbink_render_cntr "400 350 50 50" fa.ttf $'\xef\x87\x8e' # U+F1CE fa-circle-notch
        fbink_render_over "408 358 34 34" vera.ttf "FREE"
        fbink_render_cntr "450 350 100 50" vera.ttf $(h_unit $pfree)
    fi
}

# re-draw entire UI
do_draw_ui() {
    fbink_dirty=0
    fbink --quiet --clear --norefresh

    # header
    d_title
    d_logo
    d_battery

    # specs
    d_ram
    d_sd_int
    d_sd_ext
}

draw_ui() {
    local tries=3

    fbink_dirty=1

    for tries in $(seq $tries)
    do
        do_draw_ui
        if [ "$fbink_dirty" -eq 0 ]
        then
            fbink --quiet --flash --refresh '' \
                  $(rm /tmp/fbink_flash 2> /dev/null && echo --flash)
            return
        fi
    done

    fbink_error "fbink_dirty still set after $tries draw iterations"
}

# --- Main: ---

# trigger screen flash every 60s or sooner when touched
# (this is a background task)
fbink_flash_refresh_timer() {
    while sleep 1
    do
        timeout_touch 10
        touch /tmp/fbink_flash
    done
}

fbink_eval
draw_ui

# --- End of file. ---
