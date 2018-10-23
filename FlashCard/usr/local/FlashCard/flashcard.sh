#!/bin/sh

#set -x

export LD_LIBRARY_PATH="/usr/local/FlashCard:$LD_LIBRARY_PATH"
PATH="/usr/local/FlashCard:$PATH"
BASE="/mnt/onboard/.addons/flashcard"
CONFIGFILE="$BASE/flashcard.cfg"

# udev kills slow scripts
udev_workarounds() {
    if [ "$SETSID" != "1" ]
    then
        SETSID=1 setsid "$0" "$@" &
        exit
    fi

    # udev might call twice
    mkdir /tmp/FlashCard || exit
}

# nickel stuff
wait_for_nickel() {
    while ! pidof nickel || ! grep /mnt/onboard /proc/mounts
    do
      	sleep 5
    done
}

suspend_nickel() {
    mkdir /tmp/suspend-nickel && (
        pkill -SIGSTOP sickel # 3.16.10 watchdog
        pkill -SIGSTOP nickel
    )
    mkdir /tmp/suspend-nickel/"$1" || exit
    cat /dev/fb0 > /tmp/flashcard-fb0dump
}

resume_nickel() {
    rmdir /tmp/suspend-nickel/"$1"
    cat /tmp/flashcard-fb0dump > /dev/fb0
    rm /tmp/flashcard-fb0dump
    fbink -s top=0,left=0,width=1080,height=1440,wfm=GC16 --flash
    rmdir /tmp/suspend-nickel && (
        pkill -SIGCONT nickel
        pkill -SIGKILL sickel # 3.16.10 watchdog
    )
}

# config parser
config() {
    local value
    value=$(grep -E -m 1 "^$1\s*=" "$CONFIGFILE" | tr -d '\r')
    value="${value:${#1}}"
    value="${value#*=}"
    shift
    [ "$value" != "" ] && echo "$value" || echo "$@"
}


uninstall_check() {
    if [ "$(config uninstall 0)" = "1" ]
    then
        resume_nickel flashcard
        mv "$CONFIGFILE" "$BASE"/uninstalled-$(date +%Y%m%d-%H%M).cfg
        rm -f /etc/udev/rules.d/flashcard.rules
        rm -rf /usr/local/FlashCard /tmp/FlashCard
        exit
    fi
}

# random number [0-n) (max 2**63-1)
random_number() {
    local n="$1"

    # determine largest positive number
    if [ -z "${intmax:-}" ]
    then
        intmax=1
        while [ $intmax -lt $(($intmax*2)) ]
        do
            intmax=$(($intmax*2))
        done
        intmax=$((intmax*2-1))
    fi

    randwidth=$(printf "%x" $intmax)
    randwidth=$(( (${#randwidth}+1) / 2 ))

    if [ -z "${n:-}" ]
    then
        n=$intmax
    fi

    echo $((
        ( 0x$(hexdump -v -e "$randwidth"'/1 "%02x" "\n"' -n "$randwidth" /dev/urandom)
          & $intmax
        ) % $n
    ))
}

# deduplicate (and sort) arguments
dedup() {
    printf "%s\n" "$@" | sort -u
}

# show some picture(s)
show_picture() {
    for f in "$@"
    do
        fbink -g file="$f"
    done
}

# --- Deck Management: ---

#
# A deck is a multi-line string, cards are words on each line.
# Each new line doubles the probability (so worst cards last).
# Most functions below read deck from stdin and print to stdout.
#

#
# The card to display is chosen randomly.
# All cards start out with the same probability.
#
#     If you don't know a card, probability * 8.
#     If you  do   know a card, probability / 2.
#
# There is no time component so it's not really Spaced Repetition,
# just a matter of chance - with loaded dice.
#

# total sum of probability in a deck (reads deck, prints sum)
deck_sum() {
    local h=0
    local i=1
    local sum=0

    while read line
    do
        set -- $line
        sum=$(($sum + $#*$i))

        # probability limit 2**42
        if [ $h -lt 42 ]
        then
            i=$(($i*2))
            h=$(($h+1))
        fi
    done

    echo $sum
}

# pick specific card from [0..sum) (reads deck, prints card)
deck_pick() {
    local pick="$1"

    local h=0
    local i=1
    local sum=0
    local oldsum=0

    while read line
    do
        set -- $line
        oldsum=$sum
        sum=$(($sum + $#*$i))

        if [ $sum -gt $pick ]
        then
            local num=$(( ($pick-$oldsum) / $i ))
            shift $num
            echo $h $1
            break
        fi

        # probability limit 2**42
        if [ $h -lt 42 ]
        then
            i=$(($i*2))
            h=$(($h+1))
        fi
    done
}

# remove one (or more) cards from a deck
deck_remove() {
    while read line
    do
        line=" $line "
        for word in $@
        do
            line=${line/ $word / }
        done
        echo $line
    done
}

# insert one (or more) cards into a deck
deck_insert() {
    local level=$1
    shift

    local h=0

    # prepend new lines
    if [ $level -lt 0 ]
    then
        echo $(dedup $@)
    fi

    # add to existing line
    while read line
    do
        if [ $level -eq 0 ]
        then
            echo $(dedup $@ $line)
        else
            line=" $line "
            for word in $@
            do
                line=${line/ $word / }
            done
            echo $(dedup $line)
        fi

        level=$(($level-1))
    done

    # append new line
    while [ $level -gt 0 ]
    do
        echo ""
        level=$(($level-1))
    done

    [ $level -eq 0 ] && echo $(dedup $@)
}

# remove surplus empty lines and whitespace
deck_trim() {
    local h=0
    local skipped=""
    while read line
    do
        set -- $line

        # leading lines
        [ $h -eq 0 -a $# -eq 0 ] && continue
        h=$(($h+1))

        if [ $# -eq 0 ]
        then
            # maybe a trailing line
            skipped="$skipped"$'\n'
        else
            echo -n "$skipped"
            skipped=""
            echo $@
        fi
    done
}

# find a card in a deck, return card and its level
deck_grep() {
    local result=$(grep -Eno '(^| )'"$1"'( |$)')
    [ -z "${result:-}" ] && return 1
    set -- ${result/:/ }
    echo $(($1-1)) $2
}

# --- Session: ---

# (re)load config
load_config() {
    [ -z "${config_loaded:-}" ] || grep /mnt/onboard /proc/mounts || return 1 # not mounted
    config_loaded=1

    cfg_debug=$(config debug '0')
    cfg_debuglog=$(config debuglog '')
    cfg_session=$(config session '5')
    cfg_minutes=$(config minutes '1')
    cfg_pageflips=$(config pageflips '3')
    cfg_step_easy=$(config step_easy '1')
    cfg_step_hard=$(config step_hard '2')
    cfg_savefile=$(config savefile 'deck.txt')
    cfg_scheme=$(config scheme 'question.png question/{}.png answer.png answer/{}.png')
    cfg_autoimport=$(config autoimport '1')
    cfg_import_weight=$(config import_weight '50')

    # auto detect default touch zone
    set -- $(fbset | grep geometry)
    local width=$2
    local height=$3

    cfg_touch_hard=$(config touch_hard 0 0 $(($width/5*2)) $height)
    cfg_touch_easy=$(config touch_easy $(($width/5*3)) 0 $(($width/5*2)) $height)
}

# (re)load deck
load_deck() {
    cat "$BASE"/"$cfg_savefile"
}

# save deck
save_deck() {
    deck_trim > "$BASE"/"$cfg_savefile"
}

# auto-import new cards
auto_import() {
    local filesum side prefix postfix card deck missing sum weight i h

    [ "$cfg_autoimport" = "0" ] && return

    # only import if there are changes in the filesystem
    local filesum=$(find "$base" | sort | md5sum)
    filesum=$(echo "$filesum" "$cfg_scheme" | md5sum)
    [ -s "$BASE"/"$cfg_savefile" -a "$filesum" = "$donesum" ] && return
    cd "$BASE" || return

    set -- # empty argument list

    # collect cards
    for side in $cfg_scheme
    do
        prefix=${side%'{}'*}
        postfix=${side#*'{}'}

        for file in "$prefix"*"$postfix"
        do
            [ ! -e "$file" ] && continue
            card=${file:${#prefix}:$((${#file}-${#postfix}-${#prefix}))}
            set -- $@ $card
        done
    done

    set -- $(dedup $@)

    # load deck
    deck=$(load_deck)

    # are there cards in the deck that no longer exist?
    missing=$(echo $deck | deck_remove $@)
    deck=$(echo "$deck" | deck_remove $missing)

    # reverse deck_remove - remove cards already in the deck
    set -- $(echo $@ | deck_remove $deck)

    # what, no cards?
    [ $# -eq 0 ] && return

    # determine where to insert cards
    sum=$(echo "$deck" | deck_sum)
    weight=$(( $sum * $cfg_import_weight / 100 ))
    i=1
    h=0
    while [ $(($i*2)) -le $(($weight / $#)) ]
    do
        i=$(($i*2))
        h=$(($h+1))
    done

    # do insert
    echo -n "$deck" | deck_insert $h $@ | save_deck
}

# expect X seconds for touch
# return 0 if touched
# return 1 if not touched
timeout_touch() {
    local touched="not"
    read -t "$1" touched < /dev/input/event1
    [ "$touched" != "not" ]
}

#
# When the kobo enters a low-power mode,
# the timeouts no longer reflect real-time.
#
timeout_delta() {
    local now=$(date +%s)
    local target=$(($now + $1))

    while [ $now -lt $target ]
    do
        echo timeout_delta waiting $now / $target
        timeout_touch 15 && sleep 1
        now=$(date +%s)
    done
}


# wait between sessions
session_wait() {
    ( for i in $(seq 1 $cfg_pageflips)
      do
          echo got a touch: $i / $cfg_pageflips
          timeout_touch 9999 && sleep 1
      done
    ) &
    timeout_delta $(($cfg_minutes * 60))
    wait # for $cfg_pageflips
    wait_for_nickel # for usb mode

    while timeout_touch 1
    do
        : # wait for touchscreen to settle
    done
}

# --- Main: ---

main() {
    local deck card

    udev_workarounds
    wait_for_nickel
    uninstall_check
    load_config

    while session_wait
    do
        # reload_config
        load_config
        uninstall_check

        suspend_nickel flashcard
        touchgrab | (
            # kill me now
            read -t 1 touchgrabpid
            bail() {
                echo bailing $@
                kill $touchgrabpid
                exit
            }

            cd "$BASE" || bail base not found

            auto_import
            deck=$(load_deck)

            for i in $(seq 1 $cfg_session)
            do
                # pick a card
                sum=$(echo "$deck" | deck_sum)
                [ "$sum" -eq "0" ] && bail empty deck

                rand=$(random_number $sum)
                set -- $(echo "$deck" | deck_pick $rand)
                level=$1
                card=$2

                # same card? pick one more time
                if [ "$card" = "$lastcard" ]
                then
                    rand=$(random_number $sum)
                    set -- $(echo "$deck" | deck_pick $rand)
                    level=$1
                    card=$2
                fi

                last_card="$card"

                set --

                # show the card(s)
                for s in $cfg_scheme
                do
                    # file exists? this is background
                    if [ -f "$s" ]
                    then
                        set -- $@ "$s"
                        continue
                    fi

                    # this is actual card
                    s=${s/'{}'/"$card"}

                    # file doesn't exist? discard background
                    if [ ! -f "$s" ]
                    then
                        set --
                        continue
                    fi

                    # show background and card
                    show_picture $@ $s

                    # wait for touchscreen to settle
                    touched=""
                    while [ "$touched" != "not" ]
                    do
                        touched="not"
                        read -t 1 touched
                    done

                    # obtain answer
                    pickel || bail pickel is not working
                    pickel wait-for-hit $cfg_touch_easy $cfg_touch_hard
                    answer=$?
                done

                # process answer
                if [ $answer -eq 1 ]
                then
                    level=$(($level-$cfg_step_easy))
                elif [ $answer -eq 2 ]
                then
                    level=$(($level+$cfg_step_hard))
                fi

                deck=$(
                    echo "$deck" |
                    deck_remove $card |
                    deck_insert $level $card
                )
            done

            echo "$deck" | save_deck
            kill $touchgrabpid
        )
        resume_nickel flashcard
    done
}

main
