#!/usr/bin/env bash

# should not run as root
[ "$EUID" -eq 0 ] && echo "This script should NOT be run using sudo" && exit 1

# the name of this script is
SCRIPT=$(basename "$0")

# where is this script is running?
WHERE=$(dirname "$(realpath "$0")")

if [ "$#" -gt 0 ]; then
    echo "Usage: $SCRIPT"
    exit 1
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

# try to establish locales. Any patch should always retain
# "en_GB.UTF-8" so we don't pull the rug out from beneath anything
# (like Python) that already knows the default language
# (it can be removed later if need be, eg using raspi-config.
if try_patch "/etc/locale.gen" "setting locales" ; then
   sudo /usr/sbin/dpkg-reconfigure -f noninteractive locales
fi

# try to set the default language
if [ -n "$LOCALE_LANG" ] ; then
   if [ $(grep -c "^${LOCALE_LANG}" /etc/locale.gen) -gt 0 ] ; then
      echo "Setting default language to $LOCALE_LANG"
      sudo /usr/sbin/update-locale "LANG=$LOCALE_LANG"
   else
      echo "$LOCALE_LAN not active in /etc/locale.gen - unable to apply"
   fi
fi

# tell dhcpcd and docker not to fight
try_patch "/etc/dhcpcd.conf" "allowinterfaces eth*,wlan*"

# install mechanism to auto-reset physical interfaces
# this is only needed in non-NetworkManager systems
if [ $(systemctl is-active NetworkManager) = "inactive" ] ; then

   # it is only useful if rc.local is executable with non-zero length
   # (implying that it has the expected content and is patchable)
   HOOK="/etc/rc.local"
   if [ -s "$HOOK" -a -x "$HOOK" ] ; then

      # the fix can only be implemented if the mechanism exists
      # (it may have been removed in a customised PiBuilder)
      TARGET="/usr/bin/isc-dhcp-fix.sh"
      if SOURCE="$(supporting_file "$TARGET")" ; then

         echo "Installing $TARGET"
         sudo cp "$SOURCE" "$TARGET"
         sudo chown root:root "$TARGET"
         sudo chmod 555 "$TARGET"

         try_patch "$HOOK" "launch isc-dhcp-fix.sh at boot"

         # in the non-host-specific case, that patch puts the following
         # line into /etc/rc.local. It is commented-out but even if it
         # is made active, it still evaluates to a no-op
         INACTIVE="# /usr/bin/isc-dhcp-fix.sh"

         # we are going to build a replacement for that
         ACTIVE="/usr/bin/isc-dhcp-fix.sh"

         # iterate the candidate interfaces
         for I in eth0 wlan0 ; do
            if ip r | grep -q "dev $I proto" ; then
               ACTIVE="$ACTIVE $I"
            fi
         done

         # try to replace the inactive form with the active form just
         # built. The edit will not occur if the INACTIVE form is not
         # present (the most likely reason being that there was a
         # host-specific patch). Also note no .bak file is produced.
         # We want .bak to be the baseline
         echo "If $HOOK contains \"$INACTIVE\","
         echo "it will be replaced with \"$ACTIVE\"."
         sudo sed -i "s+$INACTIVE+$ACTIVE+" "$HOOK"

      fi
   fi
fi


# patch resolvconf.conf for local DNS and domain name
try_patch "/etc/resolvconf.conf" "local name servers"


# disable IPv6
#
# if NetworkManager is running then iterate the available interfaces
# and change any cases where ipv6.method is "auto" to "disabled".
# Then install the hook script
if [ "$(systemctl is-active NetworkManager)" = "active" ] ; then
   nmcli -g name connection | while read C ; do
      M="$(nmcli -g ipv6.method connection show "$C")"
      if [ "$M" = "auto" ] ; then
         echo "Disabling IPv6 on $C (was $M)"
         sudo nmcli connection modify "$C" ipv6.method "disabled"
      fi
   done
   try_merge "/etc/NetworkManager/dispatcher.d" "adding sysctl hook script"
fi

# ideally, there are no patches for sysctl.conf (old style)
try_patch "/etc/sysctl.conf" "patching sysctl.conf"
# ideally, sysctl patches are handled from sysctl.d (new style)
try_merge "/etc/sysctl.d" "customising sysctl.d"


# grub customisations for hosts booting that way. Raspberry Pis don't
# use grub so this is aimed at native/ProxMox Debian/Ubuntu.
if try_merge "/etc/default/grub.d" "customising grub.d" ; then
   if [ -x "/usr/sbin/update-grub" ] ; then
      echo "Updating GRUB"
      sudo update-grub
   else
      echo "Warning: PiBuilder patched /etc/default/grub.d but /usr/sbin/update-grub not present"
   fi
fi

# patch journald.conf to reduce endless docker-runtime mount messages
try_patch "/etc/systemd/journald.conf" "less verbose journalctl"

# merge network directory if one exists
try_merge "/etc/network" "customising network interfaces"

# handle change of controlling variable name from "DISABLE_VM_SWAP" to "VM_SWAP":
#
#  if VM_SWAP present, the value (default|disable|automatic) prevails.
#  if VM_SWAP omitted:
#     if DISABLE_VM_SWAP is true, VM_SWAP=disable
#     if DISABLE_VM_SWAP omitted or false, VM_SWAP=default
#
[ -z "$VM_SWAP" ] && [ "$DISABLE_VM_SWAP" = "true" ] && VM_SWAP=disable
is_raspberry_pi && VM_SWAP="${VM_SWAP:-automatic}" || VM_SWAP="default"


# now, how should VM be handled?
case "$VM_SWAP" in

   "disable" )

      # is swap turned on?
      if [ -n "$(/usr/sbin/swapon -s)" ] ; then

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
         if [ -n "$(/usr/sbin/swapon -s)" ] ; then

            # yes! just disable it without changing the config
            echo "Running from SD card - disabling virtual memory swapping"
            sudo dphys-swapfile swapoff
            sudo systemctl disable dphys-swapfile.service

         fi

      else

         # no, not SD. turn off swap if it is enabled
         [ -n "$(/usr/sbin/swapon -s)" ] &&  sudo dphys-swapfile swapoff

         # try to patch the swap file setup
         if try_patch "/etc/dphys-swapfile" "setting swap to max(2*physRAM,2048) GB" ; then

            # patch success! deploy
            sudo dphys-swapfile setup

         fi

         # re-enable swap (reboot occurrs soon)
         sudo dphys-swapfile swapon

      fi
      ;;

   "custom" )

      # try to patch the swap file setup
      if try_patch "/etc/dphys-swapfile" "setting swap to max(2*physRAM,2048) GB" ; then

         # patch success! turn off swap if it is enabled
         [ -n "$(/usr/sbin/swapon -s)" ] &&  sudo dphys-swapfile swapoff

         # apply configuration
         sudo dphys-swapfile setup

         # re-enable swap (reboot occurrs soon)
         sudo dphys-swapfile swapon

      else

         echo "Warning: VM_SWAP=$VM_SWAP but unable to patch /etc/dphys-swapfile"
         echo "         Virtual memory system left at OS defaults"

      fi

      ;;

   *)
      # catch-all implying "default" meaning "leave everything alone"
      echo "Virtual memory system left at OS defaults"
      ;;

esac

# run the script epilog if it exists
run_pibuilder_epilog

echo "$SCRIPT complete - rebooting..."
sudo touch /boot/ssh
sudo /usr/sbin/reboot
