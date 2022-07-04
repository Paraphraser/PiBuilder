#!/usr/bin/env bash

# support user renaming of script
SCRIPT=$(basename "$0")

# check environment
if ! which wpa_passphrase ; then
   echo "Error: $SCRIPT needs to run on a system where the wpa_passphrase command is available"
   echo "       Hint: use a Raspberry Pi"
   exit 1
fi

# check arguments
if [ "$#" -ne 2 ]; then

   echo "Usage: $SCRIPT SSID CC"
   echo ""
   echo "       - SSID is a WiFi network name (enclosed in quotes if it contains spaces)"
   echo "       - CC is a valid country code - eg AU"
   exit 1

fi

# the expected arguments are
SSID="$1"
CC=${2^^}

# the target in the current working directory is
TARGET="wpa_supplicant.conf"

# prompt for wifi password
read -s -p "Enter password for WiFi SSID $SSID: " PSK
echo ""
read -s -p "Re-enter password: " CHK_PSK
echo ""
if [ ! "$PSK" = "$CHK_PSK" ] ; then
   echo "Passwords do not match!"
   exit -1
fi

# generate the credentials
CREDENTIALS=$(wpa_passphrase "$SSID" "$PSK" | sed '/#psk=/d')

# construct the file
cat <<-ENDCONFIG >"$TARGET"
country=$CC
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

# below is output from wpa_passphrase "«SSID»" "«PSK»"
$CREDENTIALS
ENDCONFIG

# report
echo "$TARGET created - needs to be copied to /boot"
