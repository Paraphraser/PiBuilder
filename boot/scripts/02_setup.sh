#!/usr/bin/env bash

# should not run as root
[ "$EUID" -eq 0 ] && echo "This script should NOT be run using sudo" && exit -1

# the name of this script is
SCRIPT=$(basename "$0")

if [ "$#" -gt 0 ]; then
    echo "Usage: $SCRIPT"
    exit -1
fi

# declare path to support directory and import common functions
SUPPORT="/boot/scripts/support"
. "$SUPPORT/pibuilder/functions.sh"

# import user options and run the script prolog - if they exist
run_pibuilder_prolog

# clean-up any /etc/ssh.old from the previous step
if [ -d "/etc/ssh.old" ] ; then
   echo "Removing /etc/ssh.old"
   sudo rm -rf /etc/ssh.old
fi

# try to set the default language
if [ -n "$LOCALE_LANG" ] ; then
   echo "Setting default language to $LOCALE_LANG"
   sudo update-locale "LANG=$LOCALE_LANG"
fi

# tell dhcpcd and docker not to fight
try_patch "/etc/dhcpcd.conf" "allowinterfaces eth*,wlan*"

# install mechanism to auto-reset physical interfaces
TARGET="/usr/bin/isc-dhcp-fix.sh"
if SOURCE="$(supporting_file "$TARGET")" ; then

   echo "Installing $TARGET"
   sudo cp "$SOURCE" "$TARGET"
   sudo chown root:root "$TARGET"
   sudo chmod 555 "$TARGET"

   try_patch "/etc/rc.local" "launch isc-dhcp-fix.sh at boot"

   # in the non-host-specific case, that patch puts the following line
   # into /etc/rc.local. It is commented-out but even if it is made
   # active, it still evaluates to a no-op
   INACTIVE="# /usr/bin/isc-dhcp-fix.sh"

   # we are going to build a replacement for that
   ACTIVE="/usr/bin/isc-dhcp-fix.sh"

   # iterate the candidate interfaces
   for I in eth0 wlan0 ; do
     if ip r | grep -q "dev $I proto" ; then
        ACTIVE="$ACTIVE $I"
     fi
   done

   # try to replace the inactive form with the active form just built
   # the edit will not occur if the INACTIVE form is not present (the
   # most likely reason being that there was a host-specific patch).
   # Also note no .bak file is produced. We want .bak to be the baseline
   echo "If /etc/rc.local contains \"$INACTIVE\","
   echo "it will be replaced with \"$ACTIVE\"."
   sudo sed -i "s+$INACTIVE+$ACTIVE+" "/etc/rc.local"

fi

# patch resolvconf.conf for local DNS and domain name
try_patch "/etc/resolvconf.conf" "local name servers"

# patch sysctl.conf to disable IPv6
try_patch "/etc/sysctl.conf" "disable IPv6"

# patch journald.conf to reduce endless docker-runtime mount messages
try_patch "/etc/systemd/journald.conf" "less verbose journalctl"

# turn off VM swapping if requested
if [ "$DISABLE_VM_SWAP" = "true" ] && [ -n "$(swapon -s)" ] ; then
   echo "Disabling virtual memory swapping"
   sudo swapoff -a
   sudo systemctl disable dphys-swapfile.service
fi

# run the script epilog if it exists
run_pibuilder_epilog

echo "$SCRIPT complete - rebooting..."
sudo touch /boot/ssh
sudo reboot
