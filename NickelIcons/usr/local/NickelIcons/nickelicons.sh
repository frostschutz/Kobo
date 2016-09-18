#!/bin/sh

hexa() {
    hexdump -v -e '16/1 "%02x" "\n"' "$@"
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
if [ -e /mnt/onboard/.kobo/ -a ! -e /mnt/onboard/.addons/nickelicons ]
then
    rm -rf /usr/local/NickelIcons /etc/udev/rules.d/nickelicon.rules
    exit
fi

PNG_MAGIC=$(echo -en '\x89PNG\x0d\x0a\x1a\x0a' | hexa)
MNG_MAGIC=$(echo -en '\x8aMNG\x0d\x0a\x1a\x0a' | hexa)
# IEND_MAGIC=$(echo -en '\x00\x00\x00\x00IEND' | hexa)
# MEND_MAGIC=$(echo -en '\x00\x00\x00\x00MEND' | hexa)

dump() {
    local input="$1"
    local offset="$2"
    local length="$3"
    local outdir="$4"
    local type="$5"

    file="${outdir}/${offset}_${length}.${type}"

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
    local indir="$1"
    local offset="$2"
    local length="$3"
    local output="$4"
    local type="$5"

    file="${indir}/restore/${offset}_${length}.${type}"

    if [ ! -e "$file" ]
    then
        # echo "Skipping restore for non-exist '${file}'."
        return
    fi

    filesize=$(stat -c %s "$file")
    filemagic=$(hexa -n 8 "$file")

    if [ "$type" == "mng" -a "$filemagic" != "$MNG_MAGIC" ]
    then
        echo "Will not restore '${file}': not in MNG format."
        return
    elif [ "$filemagic" != "$PNG_MAGIC" ]
    then
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

    # restore
    if cat "$file" |
            dd conv=notrunc bs=1 seek="$offset" count="$length" of="$output"
    then
        echo "Successfully restored '${file}'."
        mv "$file" "$indir"/done/
    else
        echo "Failed to restore '${file}' :: error $?"
        mv "$file" "$indir"/invalid/
    fi
}

parse() {
    TARGET="$1"
    base=$(basename "$TARGET")
    dumpdir="/mnt/onboard/.addons/nickelicons/$base"

    # avoid unnecessary re-runs
    for dumped in "$dumpdir"/*.*
    do
        break
    done

    for restored in "$dumpdir"/restore/*.*
    do
        break
    done

    if [ -e "$dumped" -a ! -e "$restored" ]
    then
        echo "Not re-processing ${TARGET}: previously dumped and nothing to restore."
        return
    fi

    mkdir -p "$dumpdir"/restore "$dumpdir"/done "$dumpdir"/invalid

    # do it
    strings -o -n 3 "$TARGET" \
    | grep -E '(PNG|MNG)' \
    | while read offset line
    do
        # octal to decimal
        offset=$((0$offset - 1))

        # verify magic
        magic=$(hexa -s "$offset" -n 8 "$TARGET" bs=1 count=8 skip="$offset")

        if [ "$magic" == "$PNG_MAGIC" ]
        then
            type=png
        elif [ "$magic" == "$MNG_MAGIC" ]
        then
            type=mng
        else
            # not a known file type
            continue
        fi

        # determine length
        length=$((0x$(hexa -n 2 -s $(($offset-2)) "$TARGET")))

        if [ "$length" -gt 0 ]
        then
            dump "$TARGET" $offset $length "$dumpdir" "$type"
            restore "$dumpdir" $offset $length "$TARGET" "$type"
        fi
    done

    # leftovers would prevent unnecessary re-run optimization
    mv "$dumpdir"/restore/* "$dumpdir"/invalid
    rmdir "$dumpdir"/invalid
}

logfile=/mnt/onboard/.addons/nickelicons/report.txt

rm -f "$logfile"

strings -n 1 /mnt/onboard/.addons/nickelicons/targets.txt | grep -v ^# | while read target
do
    if [ -f "$target" ]
    then
        echo "---- $(date) ---- Processing '${target}'... ----" >> "$logfile" &&
            parse "$target" >> "$logfile"
    else
        echo "---- $(date) ---- Skipping '${target}': not a regular file. ----" >> "$logfile"
    fi
done

sync
