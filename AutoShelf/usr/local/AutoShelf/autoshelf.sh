#!/bin/sh

PATH="/usr/local/AutoShelf":"$PATH"
CONFIGFILE="/mnt/onboard/.addons/autoshelf/autoshelf.cfg"

#
# configuration
#
config() {
    local value
    value=$(grep -m 1 "^$1=" "$CONFIGFILE")
    value="${value:$((1+${#1}))}"
    [ "$value" != "" ] && echo "$value" || echo "$2"
}

# database escapes
escape() {
    echo -n "${1//'/''}"
}

like() {
    escape "$1" | sed -e 's@[%_]@\\\0@g'
}

progress() {
    while [ -e /tmp/suspend-nickel ]
    do
        pngshow /usr/local/AutoShelf/autoshelf.png
        sleep 2
        [ -e /tmp/suspend-nickel ] && pngshow /usr/local/AutoShelf/autoshelf-off.png
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
        pkill -SIGSTOP sickel # 3.16.10 watchdog
        pkill -SIGSTOP nickel
        progress &
    )
    mkdir /tmp/suspend-nickel/"$1" || exit
}

resume_nickel() {
    rmdir /tmp/suspend-nickel/"$1"
    rmdir /tmp/suspend-nickel && (
        pkill -SIGCONT nickel
        pkill -SIGKILL sickel # 3.16.10 watchdog
    )
}

autoshelf() {
    # variables from configuration file, if present
    cfg_path=$(config path /mnt/onboard:/mnt/sd)
    cfg_skip=$(config skip /mnt/onboard/.kobo)
    cfg_consume=$(config consume 1)
    cfg_series=$(config series 1)
    cfg_series_regexp=$(config series_regexp '#([^/]+)/([0-9.]+)#:\1:\2:#')
    cfg_exclusive=$(config exclusive 0)
    cfg_unique_book=$(config unique_book 1)
    cfg_uninstall=$(config uninstall 0)

    today="strftime('%Y-%m-%dT%H:%M:%f')"

    echo "
PRAGMA synchronous = OFF;
PRAGMA journal_mode = MEMORY;
BEGIN TRANSACTION;

CREATE TABLE AutoShelf AS SELECT * FROM Shelf WHERE 0;
CREATE TABLE AutoShelfContent AS SELECT * FROM ShelfContent WHERE 0;
CREATE UNIQUE INDEX autoshelf_id ON AutoShelf(Id);
CREATE UNIQUE INDEX autoshelfcontent_key ON AutoShelfContent(ShelfName, ContentId);
CREATE UNIQUE INDEX autoshelf_name ON AutoShelf(InternalName);
"

    if [ "$cfg_unique_book" == "1" ]
    then
        echo "
CREATE UNIQUE INDEX autoshelfcontent_id ON AutoShelfContent(ContentId);
"
    fi

    echo "
REPLACE INTO AutoShelf SELECT * FROM Shelf WHERE _IsDeleted!='true';
REPLACE INTO AutoShelfContent SELECT * FROM ShelfContent WHERE _IsDeleted!='true';

DELETE FROM ShelfContent WHERE _IsSynced!='true';
UPDATE Shelf SET LastModified=$today, _IsDeleted='true';
UPDATE ShelfContent SET DateModified=$today, _IsDeleted='true';
"

    if [ "$cfg_exclusive" == "1" ]
    then
        echo "
UPDATE AutoShelf SET LastModified=$today, _IsDeleted='true';
UPDATE AutoShelfContent SET DateModified=$today, _IsDeleted='true';
"
    else
        echo "
UPDATE AutoShelf SET LastModified=$today, _IsDeleted='true' WHERE InternalName LIKE '%/';
UPDATE AutoShelfContent SET DateModified=$today, _IsDeleted='true' WHERE ShelfName LIKE '%/';
"
    fi

    if [ "$cfg_uninstall" == "1" ]
    then
        echo "DELETE FROM Activity WHERE Type='Shelf' AND Id LIKE '%/';"
        cfg_path=""
    fi

    consume=""

    while [ ${#cfg_skip} -gt 0 ]
    do
        # cut off first path element
        skip=${cfg_skip#%%:*}
        cfg_skip=${cfg_skip:$((${#skip}+1))}
        consume="$consume AND ContentID NOT LIKE 'file://$(like "$skip")/%' ESCAPE '\\'"
    done

    while [ ${#cfg_path} -gt 0 ]
    do
        # cut off first path element
        this=${cfg_path%%:*}
        cfg_path=${cfg_path:$((${#this}+1))}
        path=${this%%=*}
        pathlike=$(like "$path")
        prefix=${this:$((${#path}+1))}

        sqlite3 /mnt/onboard/.kobo/KoboReader.sqlite "
            SELECT ContentID FROM content
            WHERE ContentType = 6 AND ContentID LIKE 'file://$pathlike/%' ESCAPE '\\' $consume
            ORDER BY ContentID
        ;" | while read file
        do
            escapefile=$(escape "$file")
            base=${file:$((8+${#path}))}
            shelf=$(dirname /"$base")
            shelf=${shelf:1}
            shelf="$prefix$shelf"

            if [ "$shelf" != "$prevshelf" ]
            then
                prevshelf="$shelf"
                escapeshelf=$(escape "$shelf")
                echo "
UPDATE OR IGNORE AutoShelf SET LastModified=$today, _IsDeleted='false', _IsVisible='true' WHERE InternalName='$escapeshelf/';
INSERT OR IGNORE INTO AutoShelf VALUES ($today, '$escapeshelf/','$escapeshelf/',$today,'$escapeshelf/',NULL,'false','true','false');
"
            fi

            echo "
REPLACE INTO AutoShelfContent VALUES ('$escapeshelf/', '$escapefile', $today, 'false', 'false');
"

            if [ "$cfg_series" == "1" ]
            then
                result=$(echo -n "$base" | sed -r -e s"$cfg_series_regexp")

                if [ "$result" != "$base" ]
                then
                    garbage=${result%%:*}
                    result=${result:$((${#garbage}+1))}
                    series=${result%%:*}
                    result=${result:$((${#series}+1))}
                    number=${result%%:*}

                    echo "UPDATE content
                          SET Series='$(escape "$series")', SeriesNumber='$(escape "$number")'
                          WHERE ContentID='$escapefile';"
                fi
            fi
        done

        if [ "$cfg_consume" == "1" ]
        then
            consume="$consume AND ContentID NOT LIKE 'file://$pathlike/%' ESCAPE '\\'"
        fi
    done

    echo "
REPLACE INTO Shelf SELECT * FROM AutoShelf;
REPLACE INTO ShelfContent SELECT * FROM AutoShelfContent;
DROP TABLE AutoShelf;
DROP TABLE AutoShelfContent;

COMMIT TRANSACTION;
"
}

udev_workarounds

if [ "$ACTION" == "add" ]
then
    # prompt mode
    OFF=1
    rm /tmp/autoshelf-on

    while cat /dev/input/event1 | dd bs=1 count=1
    do
        if [ -e /mnt/onboard/.kobo ]
        then
            exit
        fi

        if [ "$OFF" == "1" ]
        then
            OFF=0
            touch /tmp/autoshelf-on
            pngshow "/usr/local/AutoShelf/autoshelf.png"
        else
            OFF=1
            rm /tmp/autoshelf-on
            pngshow "/usr/local/AutoShelf/autoshelf-off.png"
        fi

        sleep 1
    done

    exit
    # exit prompt mode
elif [ "$ACTION" != "remove" ]
then
    # unknown mode
    exit
elif [ ! -e /tmp/autoshelf-on ]
then
    # disabled mode
    exit
fi

rm /tmp/autoshelf-on

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
    autoshelf > /tmp/autoshelf.sql
    cat /tmp/autoshelf.sql | sqlite3 -bail -batch -echo /mnt/onboard/.kobo/KoboReader.sqlite >& /tmp/autoshelf-sql.execution

    if [ "$(config uninstall 0)" == "1" ]
    then
        touch /mnt/onboard/.addons/autoshelf/uninstalled-$(date +%Y%M%d-%H%M)
        rm /etc/udev/rules.d/autoshelf.rules
        rm -rf /usr/local/AutoShelf
    fi
fi

resume_nickel autoshelf
