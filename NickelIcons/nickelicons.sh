#!/bin/sh

# udev kills slow scripts
if [ "$SETSID" != "1" ]
then
    SETSID=1 setsid "$0" "$@" &
    exit
fi

# PNG magic is 8 bytes: 0x89 P N G 0x0d 0x0a 0x1a 0x0a
PNG_MAGIC=$'\x89PNG\x0d\x0a\x1a\x0a'
PNG_MAGIC=$(echo -n "$PNG_MAGIC" | hexdump)

dump() {
    input="$1"
    offset="$2"
    length="$3"
    outdir="$4"

    file="${outdir}/${offset}_${length}.png"

    if [ ! -e "$file" ]
    then
        dd bs=1 skip="$offset" count="$length" if="$input" of="$file" &&
            echo "Successfully dumped '${file}'." ||
                echo "Failed to dump '${file}'. :: error $?"
    else
        echo "Skipping dump for existing '${file}'."
    fi
}

restore() {
    indir="$1"
    offset="$2"
    length="$3"
    output="$4"

    file="${indir}/${offset}_${length}.png"
    filesize=$(stat -c %s "$file")
    filemagic=$(hexdump -n 8 "$file")

    if [ ! -e "$file" ]
    then
        echo "Skipping restore for non-exist '${file}'."
    elif [ "$filemagic" != "$PNG_MAGIC" ]
    then
        # not a PNG, no restore
        echo "Will not restore '${file}': not in PNG format."
        return
    elif [ "$filesize" -lt "$length" ]
    then
        # file too large to restore
        echo "Will not restore '${file}': size {$filesize} > ${length} bytes."
        return
    fi

    # restore and pad with zeroes
    cat "$file" /dev/zero |
        dd conv=notrunc bs=1 seek="$offset" count="$length" of="$output" &&
        echo "Successfully restored '${file}'." ||
            echo "Failed to restore '${file}' :: error $?"
}

parse() {
    TARGET="$1"
    base=$(basename "$TARGET")
    dumpdir="/mnt/onboard/.nickelicons/$base"
    mkdir -p "$dumpdir"/restore

    strings -o -n 3 "$TARGET" \
    | grep PNG \
    | while read offset line
    do
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

        dump "$TARGET" $offset $length "$dumpdir"
        restore "$dumpdir"/restore $offset $length "$TARGET"
    done
}

parse /usr/local/Kobo/nickel
