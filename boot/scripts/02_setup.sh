#!/usr/bin/env bash

# should not run as root
[ "$EUID" -eq 0 ] && echo "This script should NOT be run using sudo" && exit -1

# the name of this script is
SCRIPT=$(basename "$0")

if [ "$#" -gt 0 ]; then
    echo "Usage: $SCRIPT"
    exit -1
fi

set -x

SUPPORT="/boot/scripts/support"

# clean-up any /etc/ssh.old from the previous step
if [ -d "/etc/ssh.old" ] ; then
   echo "Removing /etc/ssh.old"
   sudo rm -rf /etc/ssh.old
fi

# tell dhcpcd and docker not to fight
echo "Adding allowinterfaces eth0,wlan0 to /etc/dhcpcd.conf"
sudo sed -i.bak "\$r $SUPPORT/dhcpcd.conf.patch" /etc/dhcpcd.conf
sudo systemctl daemon-reload
sudo systemctl restart dhcpcd

# install mechanism to auto-reset physical interfaces
echo "Installing /usr/bin/isc-dhcp-fix.sh"
sudo cp "$SUPPORT/isc-dhcp-fix.sh" "/usr/bin/isc-dhcp-fix.sh"
sudo chown root:root "/usr/bin/isc-dhcp-fix.sh"
sudo chmod 555 "/usr/bin/isc-dhcp-fix.sh"

# patch rc.local to launch isc-dhcpfix.sh
SOURCE="/etc/rc.local"
PATCH="$SUPPORT/rc.local.patch"
MATCH="^# By default this script does nothing." 
if [ $(egrep -c "$MATCH" "$SOURCE") -eq 1 ] ; then
   echo "Patching /etc/rc.local to launch isc-dhcp-fix.sh at boot time"
   sudo sed -i.bak "/$MATCH/r $PATCH" "$SOURCE"
else
   echo "Warning: could not patch $SOURCE"
   sleep 5
fi

# patch resolvconf.conf for local DNS and domain name
SOURCE="/etc/resolvconf.conf"
PATCH="$SUPPORT/resolvconf.conf.patch"
MATCH="^#name_servers=127.0.0.1"
if [ $(egrep -c "$MATCH" "$SOURCE") -eq 1 ] ; then
   echo "Patching /etc/resolvconf.conf for local name servers"
   sudo sed -i.bak "/$MATCH/r $PATCH" "$SOURCE"
   sudo service dhcpcd reload
   sudo dhclient
else
   echo "Warning: could not patch $SOURCE"
   sleep 5
fi

# patch sysctl.conf to disable IPv6
# note that sudo sysctl -p is disabled. If the current session was
# initiated via IPv6 (eg from Termius) we don't want to pull the
# rug out while is is needed 
SOURCE="/etc/sysctl.conf"
PATCH="$SUPPORT/sysctl.conf.patch"
MATCH="^#net.ipv6.conf.all.forwarding=1"
if [ $(egrep -c "$MATCH" "$SOURCE") -eq 1 ] ; then
   echo "Patching /etc/sysctl.conf to disable IPv6"
   sudo sed -i.bak "/$MATCH/r $PATCH" "$SOURCE"
   # will be implemented on next reboot
else
   echo "Warning: could not patch $SOURCE"
   sleep 5
fi

echo "$SCRIPT complete - rebooting..."
sudo reboot
