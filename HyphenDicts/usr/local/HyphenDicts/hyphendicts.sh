#!/bin/sh

mkdir /tmp/HyphenDicts || exit

for i in 1 2 3 4 5
do
    if [ ! -e "/mnt/onboard/.addons/hyphendicts/ ]
    then
        sleep 2.$RANDOM
    fi
done

if [ ! -e "/mnt/onboard/.addons/hyphendicts/ ]
then
    exit
fi

#
# Step 1: copy system dic to user partition
#
for dic in /usr/share/hyphen/hyph_??_??.dic
do
    basedic=$(basename "$dic")

    # already there?
    if [ -e "/mnt/onboard/.addons/hyphendicts/""$basedic" ]
    then
        continue
    fi

    cp -p "$dic" "/mnt/onboard/.addons/hyphendicts/"
done

#
# Step 2: symlink user dic to system partition
#
for dic in /mnt/onboard/.addons/hyphendicts/hyph_??_??.dic
do
    basedic=$(basename "$dic")
    alphadic=/usr/share/hyphen/"$basedic"
    betadic=/usr/local/Kobo/hyphenDicts/${basedic:0:7}.dic

    if [ $(readlink -f "$alphadic") != "$dic" ]
    then
        rm "$alphadic"
        ln -s "$dic" "$alphadic"
    fi

    if [ $(readlink -f "$betadic") != "$dic" ]
    then
        rm "$betadic"
        ln -s "$dic" "$alphadic"
    fi

    # uninstall?
    if [ -e "/mnt/onboard/.addons/hyphendicts/uninstall" ]
    then
        cp -p "$dic" "$alphadic"
    fi
done

# uninstall?
if [ -e "/mnt/onboard/.addons/hyphendicts/uninstall" ]
then
    mv /mnt/onboard/.addons/hyphendicts/uninstall /mnt/onboard/.addons/hyphendicts/uninstalled-$(date +%Y%m%d-%H%M)
    rm /etc/udev/rules.d/hyphendicts.rules
    rm -rf /usr/local/HyphenDicts/
fi

rmdir /tmp/HyphenDicts
