#!/bin/bash

#
# parse input-event-codes.h and build "number -> name" mapping
#

parse_prefix() {
    prev=-1
    grep -F "#define ${1}_" /usr/include/linux/input-event-codes.h |
    while read define name value comment
    do
        [[ "$value" =~ ^[0-9x]+$ ]] || continue
        echo $(($value)) "$name"
    done | sort -n |
    while read value name
    do
        [ $prev = $value ] && continue
        prev=$(($prev+1))
        while [ $prev -lt $value ]
        do
            printf "0x%x\n" "${prev}"
            prev=$(($prev+1))
        done
        echo "${name#*_}"
    done
}

echo EV='"'$(parse_prefix EV)'"'

for ev in $(parse_prefix EV)
do
    set -- $(parse_prefix $ev)
    [ $# -gt 0 ] && echo $ev='"'$@'"'
done
