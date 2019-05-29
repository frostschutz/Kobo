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
    local key=$(printf "%s\0" "$1" "$2" "$3" | md5sum | head -c 8)

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
    fbink --quiet --clear
    # --norefresh \
    fbink --quiet \
          --truetype "regular=$font,size=$point,left=$left,top=$top,right=$right,bottom=$bottom" \
          "$text" ||
    fbink_error "render error $?" "$font ($point) @ $rect"
}

# --- UI: ---

# display battery status
battery() {
    local capacity=$(cat "/sys/devices/platform/pmic_battery.1/power_supply/mc13892_bat/capacity")
    local status=$(cat "/sys/devices/platform/pmic_battery.1/power_supply/mc13892_bat/status")
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
      Not?charging) info=$'\xef\x97\xa7'  ;; # U+F5E7 fa-charging-station
      *)            info=$'\xef\x8b\xbe'  ;; # U+F2FE fa-poo
    esac

    fbink_render_text "500 50 50 50" fa.ttf "$info$icon"
}

# --- Main: ---

fbink_eval

# --- End of file. ---
