#!/bin/sh

# udev kills slow scripts
if [ "$SETSID" != "1" ]
then
    SETSID=1 setsid "$0" "$@" &
    exit
fi

# udev might call twice
mkdir /tmp/WebPortal || exit

sleep 10

if [ ! -e /mnt/onboard/.webportal ]
then
    exit
fi

# uninstall
if [ -e /mnt/onboard/.webportal/uninstall ]
then
    cd /mnt/onboard/.webportal
    mv uninstall uninstalled-$(date +%Y%m%d-%H%M)
    rm -f /etc/udev/rules.d/webportal.rules
    rm -rf /usr/local/WebPortal
    sed -r -e '/^127\.0\.0\.42\s.*/d' -i /etc/hosts
    exit
fi

# vhosts (local wifi hack)
if [ -e /mnt/onboard/.webportal/vhosts.conf ]
then
    cp /etc/hosts /tmp/webportal_hosts
    sed -r -e '/^127\.0\.0\.42\s.*/d' -i /tmp/webportal_hosts
    echo 127.0.0.42 $(sed -e 's@#.*@@' /mnt/onboard/.webportal/vhosts.conf | sort) >> /tmp/webportal_hosts
    cmp /etc/hosts /tmp/webportal_hosts || cp /tmp/webportal_hosts /etc/hosts
fi

# prepare network
ifconfig lo 127.0.0.1
ip addr add 127.0.0.42 dev lo

# start webserver
httpd -f -p 127.0.0.42:80 -h /mnt/onboard/.webportal
