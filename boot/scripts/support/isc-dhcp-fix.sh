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

while true; do
    Card eth0
    sleep 1
    Card wlan0
    sleep 1
done
