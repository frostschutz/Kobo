#!/bin/sh

set -x

mkdir /tmp/fatpatch || exit
rm /etc/udev/rules.d/fatpatch.rules

TARGET=/dev/mmcblk0p3

fat32() {
    [ "$(dd bs=1 skip=$((82+$1*512)) count=8 if="$TARGET")" == "FAT32   " ]
}

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

# wait for nickel to cool down
for i in $(seq 1 10)
do
    sleep 2
    black
    sleep 2
    white
done

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

for sector in 0 1 2 3 4 5 6 7
do
    fat32 "$sector" && dd bs=1 skip=$((90+512*$sector)) count=420 if="$TARGET" of=/fatpatch/backup"$sector".bin
    fat32 "$sector" && dd bs=1 seek=$((90+512*$sector)) count=420 if=/fatpatch/fatpatch.bin of="$TARGET"
    sync
done

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
    black
    for sector in 0 1 2 3 4 5 6 7
    do
        fat32 "$sector" && dd bs=1 seek=$((90+512*"$sector")) count=420 if=/fatpatch/backup"$sector".bin of="$TARGET"
        sync
    done
    sleep 10
fi

rm -r /fatpatch/
sync
reboot
