#!/bin/sh

set -x

mkdir /tmp/fatpatch || exit
rm /etc/udev/rules.d/fatpatch.rules

TARGET=/dev/mmcblk0p3

black() {
    /fatpatch/pngshow /fatpatch/fat-clown-black.png
}

white() {
    /fatpatch/pngshow /fatpatch/fat-clown-white.png
}

while sleep 5
do
    pidof nickel && break
done

sleep 5

pkill nickel
pkill sickel
pkill fickel
pkill adobe
pkill httpd

black
white
black

umount /mnt/onboard && white && sleep 10
black

sync
dd bs=1 skip=90 count=420 if="$TARGET" of=/fatpatch/backup1.bin
dd bs=1 skip=$((90+512*6)) count=420 if="$TARGET" of=/fatpatch/backup2.bin
sync
dd bs=1 seek=90 count=420 if=/fatpatch/fatpatch.bin of="$TARGET"
dd bs=1 seek=$((90+512*6)) count=420 if=/fatpatch/fatpatch.bin of="$TARGET"
sync

# see if we messed up too badly

losetup -r /dev/loop3 "$TARGET"
mount -o ro /dev/loop3 /tmp/fatpatch && white && sleep 10
black

if [ -e /tmp/fatpatch/.kobo ]
then
    # success
    white && sleep 10
else
    # failure
    black && sleep 10
    dd bs=1 seek=90 count=420 if=/fatpatch/backup1.bin of="$TARGET"
    dd bs=1 seek=$((90+512*6)) count=420 if=/fatpatch/backup2.bin of="$TARGET"
    sync
fi

rm -r /fatpatch/
sync
reboot
