#!/bin/bash

logger "isc-dhcp-fix launched"

while [ $# -gt 0 ] ; do
   for CARD in $@ ; do
      ifconfig "$CARD" | grep -Po '(?<=inet )[\d.]+' &> /dev/null
      if [ $? != 0 ]; then
         logger "isc-dhcp-fix resetting $CARD"
         ifconfig "$CARD" up
         sleep 5
      fi
      sleep 1
   done
   sleep 1
done
