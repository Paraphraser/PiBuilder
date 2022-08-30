#!/usr/bin/env bash

# should not run as root
[ "$EUID" -eq 0 ] && echo "This script should NOT be run using sudo" && exit -1

# the name of this script is
SCRIPT=$(basename "$0")

# where is this script is running?
WHERE=$(dirname "$(realpath "$0")")

if [ "$#" -gt 0 ]; then
    echo "Usage: $SCRIPT"
    exit -1
fi

# declare path to support directory and import common functions
SUPPORT="$WHERE/support"
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
try_patch "/etc/exim4/update-exim4.conf.conf" "stop exim4 paniclog messages (when IPv6 disabled)"

# patch journald.conf to reduce endless docker-runtime mount messages
try_patch "/etc/systemd/journald.conf" "less verbose journalctl"

# handle change of controlling variable name from "DISABLE_VM_SWAP" to "VM_SWAP":
#
#  if VM_SWAP present, the value (default|disable|automatic) prevails.
#  if VM_SWAP omitted:
#     if DISABLE_VM_SWAP is true, VM_SWAP=disable
#     if DISABLE_VM_SWAP omitted or false, VM_SWAP=default
#
[ -z "$VM_SWAP" ] && [ "$DISABLE_VM_SWAP" = "true" ] && VM_SWAP=disable
VM_SWAP="${VM_SWAP:-automatic}"

# now, how should VM be handled?
case "$VM_SWAP" in

   "disable" )

      # is swap turned on?
      if [ -n "$(swapon -s)" ] ; then

         # yes! just disable it without changing the config
         echo "Disabling virtual memory swapping"
         sudo dphys-swapfile swapoff
         sudo systemctl disable dphys-swapfile.service

      fi
      ;;

   "automatic" )

      # is this Pi running from SD?
      if [ -e "/sys/class/block/mmcblk0" ] ; then

         # yes, is SD! is swap turned on?
         if [ -n "$(swapon -s)" ] ; then

            # yes! just disable it without changing the config
            echo "Running from SD card - disabling virtual memory swapping"
            sudo dphys-swapfile swapoff
            sudo systemctl disable dphys-swapfile.service

         fi

      else

         # no, not SD. turn off swap if it is enabled
         [ -n "$(swapon -s)" ] &&  sudo dphys-swapfile swapoff

         # try to patch the swap file setup
         if try_patch "/etc/dphys-swapfile" "setting swap to max(2*physRAM,2048) GB" ; then

            # patch success! deploy
            sudo dphys-swapfile setup

         fi

         # re-enable swap (reboot occurrs soon)
         sudo dphys-swapfile swapon

      fi
      ;;

   *)
      # catch-all implying "default" meaning "leave everything alone"
      echo "Virtual memory system left at Raspberry Pi OS defaults"
      ;;

esac

# run the script epilog if it exists
run_pibuilder_epilog

echo "$SCRIPT complete - rebooting..."
sudo touch /boot/ssh
sudo reboot
