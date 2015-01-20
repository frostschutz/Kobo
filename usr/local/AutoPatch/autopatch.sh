#!/bin/sh

AUTOPATCH="/usr/local/AutoPatch"
TMPFS="$AUTOPATCH/tmpfs"
PATH="$PATH:$AUTOPATCH"
FILES_TO_PATCH="/usr/local/Kobo/libnickel.so.1.0.0 /usr/local/Kobo/libadobe.so /usr/local/Kobo/librmsdk.so.1.0.0"

udev_workarounds() {
    # udev kills slow scripts
    if [ "$SETSID" != "1" ]
    then
        SETSID=1 setsid "$0" "$@" &
        exit
    fi
}

suspend_nickel() {
    mkdir /tmp/suspend-nickel && (
        pkill -SIGSTOP nickel
        cat /sys/class/graphics/fb0/rotate > /tmp/rotate-nickel
        nice /etc/init.d/on-animator.sh &
    )
    mkdir /tmp/suspend-nickel/"$1" || exit
}

resume_nickel() {
    rmdir /tmp/suspend-nickel/"$1"
    rmdir /tmp/suspend-nickel && (
        killall on-animator.sh pickle
        cat /tmp/rotate-nickel > /sys/class/graphics/fb0/rotate
        cat /sys/class/graphics/fb0/rotate > /sys/class/graphics/fb0/rotate # 180° fix
        pkill -SIGCONT nickel
    )
}

md5() {
    cat "$@" | md5sum | sed -e 's/ .*//'
}

udev_workarounds

suspend_nickel autopatch

for i in $(seq 1 10)
do
    if [ -e /mnt/onboard/.kobo/KoboReader.sqlite ]
    then
        break
    fi

    sleep 1
done

cd "$AUTOPATCH"

mkdir -p "$TMPFS" /mnt/onboard/.autopatch/failed /mnt/onboard/.autopatch/disabled
mount -t tmpfs none "$TMPFS"

uninstall=0

if [ -e /mnt/onboard/.autopatch/uninstall ]
then
    uninstall=1
    rm /mnt/onboard/.autopatch/uninstall
    mv /mnt/onboard/.autopatch /mnt/onboard/.autopatch-uninstall-$(date +%s)
fi

reboot=0

for file in $FILES_TO_PATCH
do
    rm "$TMPFS"/*

    base=$(basename "$file")
    filemd5=$(md5 "$file")
    patchmd5=$(md5 /mnt/onboard/.autopatch/"$base"*.patch)

    if [ -e "$base"-"$filemd5"-"$patchmd5" ]
    then
        # already done
        continue
    fi

    # Prepare file for applying patches.
    tmpfile="$TMPFS"/"$base"
    cp "$file" "$tmpfile" || break

    if [ -e "$base"-"$filemd5"-undo ]
    then
        # Revert previous patch.
        cd "$TMPFS" # busybox bug
        base64-patch "$base" "$AUTOPATCH"/"$base"-"$filemd5"-undo || continue
        cd "$AUTOPATCH"
    fi

    cp "$tmpfile" "$tmpfile"-original

    # Apply patches one by one.
    for patch in /mnt/onboard/.autopatch/"$base"*.patch
    do
        if [ ! -f "$patch" ]
        then
            continue
        fi

        mv "$patch" "$patch".todo || continue

        patch32lsb  -i "$tmpfile" -o "$tmpfile" -p "$patch".todo >& "$TMPFS"/output && mv "$patch".todo "$patch" && continue

        # patch failed to apply
        mv "$patch".todo /mnt/onboard/.autopatch/failed/$(basename "$patch")
        mv "$TMPFS"/output /mnt/onboard/.autopatch/failed/$(basename "$patch").log
    done

    # If any changes were made, save.
    newmd5=$(md5 "$tmpfile")
    newpatchmd5=$(md5 /mnt/onboard/.autopatch/"$base"*.patch)

    if [ "$newmd5" != "$filemd5" ]
    then
        base64-diff "$tmpfile" "$tmpfile"-original > "$TMPFS"/"$base"-"$newmd5"-undo
        rm "$tmpfile"-original
        mv "$tmpfile" "$file" || continue
        reboot=1
        rm "$base"-*
        test -s "$TMPFS"/"$base"-"$newmd5"-undo && mv "$TMPFS"/"$base"-"$newmd5"-undo "$AUTOPATCH"
    fi

    touch "$base"-"$newmd5"-"$newpatchmd5"
    sync
done

umount "$TMPFS"

if [ "$uninstall" == "1" ]
then
    rm /etc/udev/rules.d/autopatch.rules
    rm -rf /usr/local/AutoPatch
    sync
fi

if [ "$reboot" == "1" ]
then
    #reboot
    resume_nickel autopatch
else
    resume_nickel autopatch
fi
