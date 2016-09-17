#!/bin/sh

if [ -e /mnt/onboard/.kobo/udevlog-uninstall.txt ]
then
    touch /mnt/onboard/.kobo/udevlog-uninstalled-$(date +%Y%m%d-%H%M).txt
    rm /etc/udev/rules.d/udevlog.rules
    rm /udevlog*
    exit
fi

(
echo -------- "$0" / "$DRIVER" / "$ACTION" / $(date) --------
printf "%s " $(set)
echo
) >> /udevlog.txt

cp /udevlog.txt /mnt/onboard/.kobo/udevlog.txt

