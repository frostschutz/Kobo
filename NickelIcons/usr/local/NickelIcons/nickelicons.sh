#!/bin/sh

hexa() {
    hexdump -e '16/1 "%02x" "\n"' "$@"
}

# udev kills slow scripts
if [ "$SETSID" != "1" ]
then
    SETSID=1 setsid "$0" "$@" &
    exit
fi

# wait for onboard to be mounted
while [ ! -e /mnt/onboard/.kobo/ ]
do
    sleep 5
done

# uninstall?
if [ -e /mnt/onboard/.kobo/ -a ! -e /mnt/onboard/.nickelicons ]
then
    rm -rf /usr/local/NickelIcons /etc/udev/rules.d/nickelicon.rules
    exit
fi

# PNG magic is 8 bytes: 0x89 P N G 0x0d 0x0a 0x1a 0x0a
PNG_MAGIC=$'\x89PNG\x0d\x0a\x1a\x0a'
PNG_MAGIC=$(echo -n "$PNG_MAGIC" | hexa)

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

    file="${indir}/restore/${offset}_${length}.png"

    if [ ! -e "$file" ]
    then
        # echo "Skipping restore for non-exist '${file}'."
        return
    fi

    filesize=$(stat -c %s "$file")
    filemagic=$(hexa -n 8 "$file")

    if [ "$filemagic" != "$PNG_MAGIC" ]
    then
        # not a PNG, no restore
        echo "Will not restore '${file}': not in PNG format."
        return
    elif [ "$filesize" -gt "$length" ]
    then
        # file too large to restore
        echo "Will not restore '${file}': size ${filesize} > ${length} bytes."
        return
    fi

    # text file busy hack
    if [ "$busyhack" != "$output" ]
    then
        if dd if="$output" of="$output" conv=notrunc count=0
        then
            # not busy - do naught
            busyhack="$output"
        else
            # busy file - full copy
            echo "Creating a copy of '${output}' to be modified..."
            cp -a "$output" "$output".busy && mv "$output".busy "$output"
            rm "$output".busy && echo "...failed to make necessary copy. :-("
            busyhack="$output"
        fi
    fi

    # restore and pad with zeroes
    cat "$file" /dev/zero |
        dd conv=notrunc bs=1 seek="$offset" count="$length" of="$output" &&
        echo "Successfully restored '${file}'." ||
            echo "Failed to restore '${file}' :: error $?"

    # move the file regardless of success to prevent pointless retries
    mv "$file" "$indir"/done
}

parse() {
    TARGET="$1"
    base=$(basename "$TARGET")
    dumpdir="/mnt/onboard/.nickelicons/$base"
    mkdir -p "$dumpdir"/restore "$dumpdir"/done

    # avoid unnecessary re-runs
    for dumped in "$dumpdir"/*.png
    do
        break
    done

    for restored in "$dumpdir"/restore/*.png
    do
        break
    done

    if [ -e "$dumped" -a ! -e "$restored" ]
    then
        echo "Not re-processing ${TARGET}: previously dumped and nothing to restore."
        return
    fi

    # do it
    strings -o -n 3 "$TARGET" \
    | grep PNG \
    | while read offset line
    do
        # octal to decimal
        offset=$((0$offset - 1))

        # verify magic
        magic=$(hexa -s "$offset" -n 8 "$TARGET" bs=1 count=8 skip="$offset")

        if [ "$magic" != "$PNG_MAGIC" ]
        then
            # not a PNG
            continue
        fi

        # determine length
        length=$((0x$(hexa -n 2 -s $(($offset-2)) "$TARGET")))

        dump "$TARGET" $offset $length "$dumpdir"
        restore "$dumpdir" $offset $length "$TARGET"
    done

    # leftovers would prevent unnecessary re-run optimization
    mkdir "$dumpdir"/invalid
    mv "$dumpdir"/restore/* "$dumpdir"/invalid
    rmdir "$dumpdir"/invalid
}

logfile=/mnt/onboard/.nickelicons/report.txt

rm "$logfile"

strings -n 1 /mnt/onboard/.nickelicons/targets.txt | grep -v ^# | while read target
do
    if [ -f "$target" ]
    then
        echo "---- $(date) ---- Processing '${target}'... ----" >> "$logfile" &&
            parse "$target" >> "$logfile"
    else
        echo "---- $(date) ---- Skipping '${target}': not a regular file. ----" >> "$logfile"
    fi
done
