#!/bin/sh

if [ "$#" = "3" -a "$0" = "/sbin/dd" -a "$1" = "if=/dev/mmcblk0p3" -a "$2" = "bs=512" -a "$3" = "count=1" ]
then
    setsid /usr/local/ScreenSaver/scanline.sh &
fi

exec /bin/dd "$@"
