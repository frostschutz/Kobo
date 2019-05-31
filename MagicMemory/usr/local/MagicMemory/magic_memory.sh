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

# --- FBInk Helpers: ---

# grab fbink variables: {view,screen}{Width,Height}, DPI, BPP, device{Name,Id,Codename,Platform}, ...
fbink_eval() {
    eval $(fbink --quiet --eval)
}

# draw something and grab its coordinates lastRect_{Top,Left,Width,Height}
fbink_rect() {
    eval $(fbink --quiet --coordinates --norefresh "$@")
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
    local left=$(($1 * $viewWidth / 600))
    local top=$(($2 * $viewHeight / 800))
    local width=$(($3 * $viewWidth / 600))
    local height=$(($4 * $viewHeight / 800))
    local right=$(($viewWidth - $left - $width))
    local bottom=$(($viewHeight - $top - $height))

    # grab pointsize from cache
    local key=$(printf "%s\0" "$font" "$text" "$width" "$height" | md5sum | head -c 8)
    local point=${point_cache#*$key=}
    point=${point%% *}

    # or re-detect pointsize (dirty)
    if [ -z $point ]
    then
        fbink_dirty=1
        for point in $(seq 2 100)
        do
            lastRect_Width=9$width
            lastRect_Height=9$height
            fbink_rect --truetype "regular=$font,size=$point" "$text"
            [ $lastRect_Width -gt $width -o $lastRect_Height -gt $height ] && break
        done
        point=$(($point-1))
        point_cache="$point_cache $key=$point "
    fi

    # actually draw it out
    fbink --quiet --norefresh $extra_args \
          --truetype "regular=$font,size=$point,left=$left,top=$top,right=$right,bottom=$bottom" \
          "$text" ||
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
    fbink_render_text "150 50 300 50" vera.ttf "Magic Memory" --centered
}

# display ram
d_ram() {
    # ram:
    set -- $(grep MemTotal /proc/meminfo) 0 0
    local ramsize=$(($2*1024))

    fbink_render_cntr "100 150 50 50" fa.ttf $'\xef\x8b\x9b' # U+F538 fa-microchip
    fbink_render_over "110 160 30 30" vera.ttf "RAM"
    fbink_render_cntr "150 150 50 50" vera.ttf $(h_unit "$ramsize")
}

# display internal sd card
d_sd_int() {
    set -- $(cat /sys/block/mmcblk0/size) 0
    local intsize=$(($1*512))

    fbink_render_cntr "250 150 50 50" fa.ttf $'\xef\x9f\x82' # U+F7C2 fa-sd-card
    fbink_render_over "260 170 30 30" vera.ttf "INT"

    if [ $intsize -gt 0 ]
    then
        fbink_render_cntr "300 150 50 50" vera.ttf $(h_unit "$intsize")
    else
        fbink_render_over "250 150 50 50" fa.ttf $'\xef\x9c\x95' # U+F715 fa-slash
        fbink_render_cntr "300 150 50 50" fa.ttf $'\xef\x81\xa5' # U+F065 fa-expand
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
        fbink_render_cntr "450 150 50 50" vera.ttf $(h_unit "$extsize")
    else
        fbink_render_over "400 150 50 50" fa.ttf $'\xef\x9c\x95' # U+F715 fa-slash
        fbink_render_cntr "450 150 50 50" fa.ttf $'\xef\x81\xa5' # U+F065 fa-expand
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
        if [ "$fbink_dirty" -eq 1 ]
        then
            do_draw_ui
        else
            fbink --quiet --refresh ''
            return
        fi
    done

    fbink_error "fbink_dirty still set after $tries draw iterations"
}

# --- Main: ---

fbink_eval
draw_ui

# --- End of file. ---
