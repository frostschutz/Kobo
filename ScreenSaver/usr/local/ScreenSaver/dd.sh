#!/bin/sh

#
# This used to be the scanline hook for 3.1x firmware.
#

ln -f -s /bin/dd /sbin/dd
exec /bin/dd "$@"
