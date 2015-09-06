#!/bin/sh

# called by /sbin/dd -> /usr/local/ScreenSaver/dd.sh

PATH="/usr/local/ScreenSaver:$PATH"
CONFIGFILE="/mnt/onboard/.addons/screensaver/screensaver.cfg"

#
# configuration
#
config() {
    local value
    value=$(grep "^$1=" "$CONFIGFILE")
    value="${value:$((1+${#1}))}"
    [ "$value" != "" ] && echo "$value" || echo "$2"
}

#
# avoid calling the hook
#
dd() {
    /bin/dd "$@" 2> /dev/null
}

#
# force screen refresh
#
refresh() {
    # I'm too lazy, draw black/white for now.
    pngshow /usr/local/ScreenSaver/1px-black.png
    pngshow /usr/local/ScreenSaver/1px-white.png
}

#
# set framebuffer geometry variables
#
geometry() {
    set -- $(fbset | grep geometry)
    width=$2
    widthbs=$(($2*2))
    height=$3
    line=$4
    linebs=$(($4*2))
}

#
# visualize the scanline
#
draw() {
    offset=$1

    dd bs="$linebs" seek=$(($offset-1)) count=1 if=/dev/urandom of=/dev/fb0
    dd bs="$linebs" seek=$(($offset+1)) count=1 if=/dev/urandom of=/dev/fb0

    refresh
}

#
# grab the pattern
#
pattern() {
    offset=$1

    set -- $(
    hexdump -v -e $line'/2 "%04x " "\n"' -s $(($linebs*$offset)) -n $widthbs /dev/fb0 \
    | md5sum
    )

    echo "$1"

    # visual pattern:
    #    | sed -r -e 's/  */ /g' -e 's/[0-7][0-9a-f]{3} /b/g' -e 's/[0-9a-f]{4} /w/g' \
    #             -e 's/w{5}w*/W/g' -e 's/b{5}b*/B/g'
}

offset=$(config offset 1)
debug=$(config debug 0)

for delay in $(config delay 0)
do
    sleep $delay
    geometry
    pattern=$(pattern $offset)

    if [ "$debug" == "1" ]
    then
        draw $offset
        echo $pattern >> /mnt/onboard/.addons/screensaver/scanline.txt
    fi

    # pngshow here
done

# hexdump -v -e '1088/2 "%04x " "\n"' -n $((1088*2*1440)) < /dev/fb0 | sed -r -e 's@0000 @X@g' -e 's@[0-9a-f]{4} ?@ @g' -e 's@........$@@' > /mnt/onboard/.ScreenSaver/hexdump.txt
