#!/usr/bin/env bash

# Refer https://www.raspberrypi.com/documentation/computers/getting-started.html#manual-ssh-setup
# (URL checked 2026-11-09)
# In theory this is still relevant to Raspberry Pi OS (Trixie).

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
   exit 1
fi

# encrypt the password
HASH=$(echo "$NEW_PASSWORD" | openssl passwd -6 -stdin)

# construct the required file
echo "$USER:$HASH" >"$TARGET"

# report
cat <<-REPORT

	$TARGET created with the following content:

	   $(cat "$TARGET")

	That file needs to be copied to the target drive. For safety, copy it to both:

	   /boot/$TARGET
	   /boot/firmware/$TARGET

	Also consider doing both of the following on the target drive:

	   \$ touch /boot/ssh
	   \$ touch /boot/firmware/ssh

REPORT
