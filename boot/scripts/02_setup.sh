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

fi

# patch resolvconf.conf for local DNS and domain name
try_patch "/etc/resolvconf.conf" "local name servers"

# patch sysctl.conf to disable IPv6
try_patch "/etc/sysctl.conf" "disable IPv6"

# run the script epilog if it exists
run_pibuilder_epilog

echo "$SCRIPT complete - rebooting..."
sudo touch /boot/ssh
sudo reboot
