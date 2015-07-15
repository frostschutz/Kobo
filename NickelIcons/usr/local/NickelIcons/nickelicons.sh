#!/bin/sh

set -x

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
PNG_MAGIC=$(echo -en '\x89PNG\x0d\x0a\x1a\x0a' | hexa)
MNG_MAGIC=$(echo -en '\x8aMNG\x0d\x0a\x1a\x0a' | hexa)
IEND_MAGIC=$(echo -en '\x00\x00\x00\x00IEND' | hexa)
MEND_MAGIC=$(echo -en '\x00\x00\x00\x00MEND' | hexa)
ZERO_MAGIC=$(echo -en '\x00\x00\x00\x00\x00\x00\x00\x00' | hexa)

dump() {
    local input="$1"
    local offset="$2"
    local length="$3"
    local outdir="$4"

    file="${outdir}/${offset}_${length}.${FILETYPE}"

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

    file="${indir}/restore/${offset}_${length}.${FILETYPE}"

    if [ ! -e "$file" ]
    then
        # echo "Skipping restore for non-exist '${file}'."
        return
    fi

    filesize=$(stat -c %s "$file")
    filemagic=$(hexa -n 8 "$file")

    if [ "$FILETYPE" == "png" -a "$filemagic" != "$PNG_MAGIC" ]
    then
        # not a PNG, no restore
        echo "Will not restore '${file}': not in PNG format."
        return
    elif [ "$FILETYPE" == "mng" -a "$filemagic" != "$MNG_MAGIC" ]
    then
        # not a MNG
        echo "Will not restore '${file}': not in MNG format."
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

    # restore without padding zeroes, so original IEND remains intact
    if cat "$file" |
            dd conv=notrunc bs=1 seek="$offset" count="$length" of="$output"
    then
        echo "Successfully restored '${file}'."
        mv "$file" "$indir"/done
    else
        echo "Failed to restore '${file}' :: error $?"
        mv "$file" "$indir"/invalid
    fi
}

parse() {
    TARGET="$1"
    base=$(basename "$TARGET")
    dumpdir="/mnt/onboard/.nickelicons/$base"

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

    # do it
    mkdir -p "$dumpdir"/restore "$dumpdir"/done "$dumpdir"/invalid
    local start=0
    local length=0
    local offset=0
    FILETYPE=png

    strings -o -n 3 "$TARGET" \
    | grep -E '(PNG|IEND|MNG|MEND)' \
    | while read offset line
    do
        # octal to decimal
        offset=$((0$offset))

        # find start offset
        if [ "$line" == "PNG" -o "$line" == "MNG" ]
        then
            # verify magic
            magic=$(hexa -s $(($offset-1)) -n 8 "$TARGET")

            if [ "$magic" == "$PNG_MAGIC" -o "$magic" == "$MNG_MAGIC" ]
            then
                # dump previous match
                if [ "$length" -gt 0 ]
                then
                    echo "== '$oldlen' '$(($start-2))' '$TARGET'"
                    oldlen=$((0x$(hexa -n 2 -s $(($start-2)) "$TARGET")))
                    exit
                    if [ "$oldlen" != "$length" ]
                    then
                        echo "$start :: new = $length old = $oldlen"
                    fi

                    dump "$TARGET" $start $length "$dumpdir"
                    restore "$dumpdir" $start $length "$TARGET"
                fi

                start=$(($offset-1))
                length=0
                FILETYPE=png

                if [ "$line" == "MNG" ]
                then
                    FILETYPE=mng
                fi
            fi
        elif [ "${line:0:4}" == "IEND" -o "${line:0:4}" == "MEND" ]
        then
            magic=$(hexa -s $(($offset-4)) -n 8 "$TARGET")

            if [ "$magic" == "$IEND_MAGIC" -o "$magic" == "$MEND_MAGIC" ]
            then
                length=$(($offset+8-$start))
            fi
        fi

        # FIXME: dump final match
    done

    # leftovers would prevent unnecessary re-run optimization
    mv "$dumpdir"/restore/* "$dumpdir"/invalid
    rmdir "$dumpdir"/invalid
}

logfile=/mnt/onboard/.nickelicons/report.txt

rm -f "$logfile"

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

sync
