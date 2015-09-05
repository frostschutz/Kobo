#!/bin/sh

PATH="/usr/local/ScreenSaver:$PATH"

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

    geometry

    if [ "$offset" -gt 0 ]
    then
        dd bs="$linebs" seek=$(($offset-1)) count=3 if=/dev/zero of=/dev/fb0
    fi

    tr '\x00' '\xff' < /dev/zero | dd bs="$linebs" seek="$offset" count=1 of=/dev/fb0

    refresh
}

#
# grab the pattern
#
pattern() {
    offset=$1

    geometry

    hexdump -v -e $line'/2 "%04x " "\n"' -s $(($linebs*$offset)) -n $widthbs /dev/fb0 \
    | sed -r -e 's/  */ /g' -e 's/[0-7][0-9a-f]{3} /b/g' -e 's/[0-9a-f]{4} /w/g' \
             -e 's/w{5}w*/W/g' -e 's/b{5}b*/B/g'
}

pattern 1334
#draw 650
# draw 1334

# hexdump -v -e '1088/2 "%04x " "\n"' -n $((1088*2*1440)) < /dev/fb0 | sed -r -e 's@0000 @X@g' -e 's@[0-9a-f]{4} ?@ @g' -e 's@........$@@' > /mnt/onboard/.ScreenSaver/hexdump.txt
