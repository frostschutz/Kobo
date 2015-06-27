#!/bin/sh

# for pickel from nickel
eval $(xargs -0 < /proc/$(pidof nickel)/environ)
export PLATFORM PRODUCT
PATH="/usr/local/AutoShelf":"$PATH"

progress() {
    [ $PRODUCT != trilogy ] && PREFIX=$PRODUCT-
    local i=0
    while [ -e /tmp/suspend-nickel ]
    do
        i=$((($i+10)%11)) # backwards
        nice zcat /etc/images/"$PREFIX"on-"$i".raw.gz | /usr/local/Kobo/pickel showpic 1
        sleep 2
    done
}

udev_workarounds() {
    # udev kills slow scripts
    if [ "$SETSID" != "1" ]
    then
        SETSID=1 setsid "$0" "$@" &
        exit
    fi
}

suspend_nickel() {
    mkdir /tmp/suspend-nickel && (
        pkill -SIGSTOP nickel
        cat /sys/class/graphics/fb0/rotate > /tmp/rotate-nickel
        progress &
    )
    mkdir /tmp/suspend-nickel/"$1" || exit
}

resume_nickel() {
    rmdir /tmp/suspend-nickel/"$1"
    rmdir /tmp/suspend-nickel && (
        killall pickel
        cat /tmp/rotate-nickel > /sys/class/graphics/fb0/rotate
        cat /sys/class/graphics/fb0/rotate > /sys/class/graphics/fb0/rotate # 180° fix
        pkill -SIGCONT nickel
    )
}

autoshelf() {
    echo "PRAGMA synchronous = OFF;"
    echo "PRAGMA journal_mode = MEMORY;"
    echo "BEGIN TRANSACTION;"

    echo "DELETE FROM Shelf WHERE InternalName LIKE '%/';"
    echo "DELETE FROM ShelfContent WHERE ShelfName LIKE '%/';"

    local i=0

    if [ -e /mnt/onboard/.autoshelf-uninstall ]
    then
        echo "DELETE FROM Activity WHERE Type='Shelf' AND Id LIKE '%/';"
        echo "END TRANSACTION;"
        return
    fi

    sqlite3 /mnt/onboard/.kobo/KoboReader.sqlite "
    SELECT ContentID FROM content
    WHERE ContentType = 6
      AND ContentID LIKE 'file:///mnt/%'
    ORDER BY ContentID
    ;" | while read file
    do
        i=$(($i+1))
        date="strftime('%Y-%m-%dT%H:%M:%SZ','now','-$i minute')"
        file=$(echo "$file" | sed -e "s@'@''@g")
        shelf=$(dirname "$file" | sed -r -e 's@^file://*mnt//*(onboard|sd)/*@@')
        word=$(basename "$file")
        for number in $word; do break; done

        if [ "$shelf" == "" ]
        then
            series="$word"
        else
            series="$shelf"
        fi

        if [ "$shelf" != "$prevshelf" ]
        then
            prevshelf="$shelf"
            echo "REPLACE INTO Shelf VALUES($date,'$shelf/','$shelf/',$date,'$shelf/',NULL,'false','true','false');"
        fi

        echo "INSERT INTO ShelfContent VALUES('$shelf/','$file',$date,'false','false');"

        echo "
        UPDATE content
        SET Series='$series', SeriesNumber='$number'
        WHERE ContentID='$file'
        ;"
    done

    echo "END TRANSACTION;"
}

udev_workarounds

suspend_nickel autoshelf

for i in $(seq 1 10)
do
    if [ -e /mnt/onboard/.kobo/KoboReader.sqlite ]
    then
        break
    fi

    sleep 1
done

if [ -e /mnt/onboard/.kobo/KoboReader.sqlite ]
then
    result=$(autoshelf)

    if echo "$result" | md5sum -c /usr/local/AutoShelf/md5sum
    then
        echo "Already done..."
    else
        echo "Updating database..."
        echo "$result" | md5sum > /usr/local/AutoShelf/md5sum
        echo "$result" | sqlite3 /mnt/onboard/.kobo/KoboReader.sqlite
    fi

    if [ -e /mnt/onboard/.autoshelf-uninstall ]
    then
        mv /mnt/onboard/.autoshelf-uninstall /mnt/onboard/.autoshelf-uninstalled-$(date +%Y%M%d-%H%M)
        rm /etc/udev/rules.d/autoshelf.rules
        rm -rf /usr/local/AutoShelf
    fi
fi

resume_nickel autoshelf
