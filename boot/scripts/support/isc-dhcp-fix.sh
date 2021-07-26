#!/bin/bash

logger "isc-dhcp-fix launched"

Card()
{
ifconfig $1 | grep -Po '(?<=inet )[\d.]+' &> /dev/null
    if [ $? != 0 ]; then
        logger "isc-dhcp-fix resetting $1"
        sudo dhclient $1
    fi
}

# if you do not have both interfaces active, comment-out the "Card"
# line that you don't need. But leave both "sleep" lines in place.
# The idea is that each interface is probed at two-second intervals.
# That should not change, even if you reduce to one interface.
while true; do
    Card eth0
    sleep 1
    Card wlan0
    sleep 1
done
