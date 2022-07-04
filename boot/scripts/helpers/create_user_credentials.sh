#!/usr/bin/env bash

# support user renaming of script
SCRIPT=$(basename "$0")

# default user is pi
USER=${1:-"pi"}

# check the environment
TEST=$(echo "test" | openssl passwd -6 -stdin 2>/dev/null)
if [ $? -ne 0 ] ; then
   echo "Error: $SCRIPT needs to run on a system where the openssl supports the -6 option"
   echo "       Hint: use a Raspberry Pi"
   exit 1
fi

# the target in the current working directory is
TARGET="userconf.txt"

# prompt for password
read -s -p "Enter password for user $USER: " NEW_PASSWORD
echo ""
read -s -p "Re-enter password: " CHK_PASSWORD
echo ""
if [ ! "$NEW_PASSWORD" = "$CHK_PASSWORD" ] ; then
   echo "Passwords do not match!"
   exit -1
fi

# encrypt the password
HASH=$(echo "$NEW_PASSWORD" | openssl passwd -6 -stdin)

# construct the required file
echo "$USER:$HASH" >"$TARGET"

# report
echo "$TARGET created - needs to be copied to /boot"
