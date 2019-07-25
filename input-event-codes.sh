#!/bin/bash

#
# parse input-event-codes.h and build "number -> name" mapping
#

parse_prefix() {
    prev=-1
    sed -e 's@ BTN_@ KEY_BTN_@g' /usr/include/linux/input-event-codes.h |
    grep -F "#define ${1}_" |
    while read define name value comment
    do
        [[ "$value" =~ ^[0-9xa-fA-F]+$ ]] || continue
        echo $(($value)) "$name"
    done |
    while read value name
    do
        [ $prev -gt $value ] && echo "$name appeared out of order: $prev > $value ..." >&2 && continue
        [ $prev = $value ] && echo -n "/${name#*_}" && continue
        printf "\n"
        prev=$(($prev+1))
        while [ $prev -lt $value ]
        do
            printf "0x%x\n" "${prev}"
            prev=$(($prev+1))
        done
        echo -n "${name#*_}"
    done |
    sed -r -e 's@[^\s]*/@@g'
}

set -- $(parse_prefix EV)

echo EV='"'$@'"'

for ev in $(parse_prefix EV)
do
    set -- $(parse_prefix $ev)
    [ $# -gt 0 ] && echo EV_$ev='"'$@'"'
done
