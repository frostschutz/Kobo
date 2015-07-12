#!/bin/sh

set -x

# PNG magic is 8 bytes: 0x89 P N G 0x0d 0x0a 0x1a 0x0a
PNG_MAGIC=$'\x89PNG\x0d\x0a\x1a\x0a'
PNG_MAGIC=$(echo -n "$PNG_MAGIC" | hexdump)
TARGET=/usr/local/Kobo/nickel
SOURCE=/mnt/onboard/.nickelicons

dump() {
    strings -o -n 3 "$TARGET" \
    | grep PNG \
    | while read offset line
    do
        echo offset is "$offset"
        echo line is "$line"

        # octal to decimal
        offset=$((0$offset - 1))

        # verify magic
        magic=$(dd if="$TARGET" bs=1 count=8 skip="$offset" | hexdump)

        if [ "$magic" != "$PNG_MAGIC" ]
        then
            # not a PNG
            continue
        fi

        # determine length
        length=$( (dd if="$TARGET" bs=1 count=1 skip=$(($offset-1));
                   dd if="$TARGET" bs=1 count=1 skip=$(($offset-2))) | od -A n -d)
        length=$((0+$length))

        # dump
        dd bs=1 skip="$offset" count="$length" if="$TARGET" of="/mnt/onboard/.nickelicons/${offset}_${length}.png"
    done
}

dump
