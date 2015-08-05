#!/bin/sh

if grep reboot /usr/local/Kobo/sickel
then
    sed -i -e s@reboot@rebarf@g /usr/local/Kobo/sickel
    killall sickel
fi

rm /etc/udev/rules.d/disablesickel.rules
rm /disablesickel.sh
