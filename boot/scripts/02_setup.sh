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

# declare path to support and helper directories
SUPPORT="$WHERE/support"
HELPERS="$WHERE/helpers"

# import common functions
. "$SUPPORT/pibuilder/functions.sh"

# import user options and run the script prolog - if they exist
run_pibuilder_prolog

# clean-up any /etc/ssh.old from the previous step
if [ -d "/etc/ssh.old" ] ; then
   echo "Removing /etc/ssh.old"
   sudo rm -rf /etc/ssh.old
fi

# locales are an ongoing problem. The goalposts keep moving between
# OS releases (eg Buster-Bullseye-Bookworm). The problem is compounded
# by the Raspberry Pi (effectively) depending on "en_GB.UTF-8" being
# active while Debian installs (eg on Proxmox) seems to activate your
# "local" locale (eg mine has en_AU.UTF-8 UTF-8).
#
# New process. If /etc/locale.conf exists it is used as an input to
# a helper script which generates editing instructions for sed to apply
# to /etc/locale.gen, otherwise fallback to the patch mechanism but
# with a deprecation warning.
#
# Whatever you do, DO NOT remove "en_GB.UTF-8" from the list of active
# locales if you are running on a Raspberry Pi. It does not like it!

if SOURCE="$(supporting_file "/etc/locale.conf")" ; then
   sudo $HELPERS/edit_locales.sh "$SOURCE"
   if [ $? -eq 0 ] ; then
      echo "Regenerating locales based on $SOURCE"
      sudo /usr/sbin/dpkg-reconfigure -f noninteractive locales
   fi
else
   if try_patch "/etc/locale.gen" "patching locales" ; then
      echo "WARNING: patching locales is deprecated. Use the locale.conf mechanism"
      echo "         (see PiBuilder documentation for details)"
      sudo /usr/sbin/dpkg-reconfigure -f noninteractive locales
   fi
fi

# try to set the default language
TARGET="/etc/locale.gen"
if [ -n "$LOCALE_LANG" -a -f "$TARGET" ] ; then
   if [ $(grep -c "^${LOCALE_LANG}" "$TARGET") -gt 0 ] ; then
      echo "Setting default language to $LOCALE_LANG"
      sudo /usr/sbin/update-locale "LANG=$LOCALE_LANG"
   else
      echo "$LOCALE_LAN not active in /etc/locale.gen - unable to apply"
   fi
fi


if ! is_NetworkManager_running ; then

   # tell dhcpcd and docker not to fight
   try_patch "/etc/dhcpcd.conf" "allowinterfaces eth*,wlan*"

   # install mechanism to auto-reset physical interfaces
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
# if NetworkManager is running then:
# 1. iterate the available interfaces and change any cases where
#    ipv6.method is "auto" to "ignore".
# 2. install the hook script which enforces sysctl settings in a
#    NetworkManager environment.
# 3. run a local customisations script (eg to set static IP addresses) 
#
if is_NetworkManager_running ; then

   # disable IPv6
   nmcli -g name connection | while read C ; do
      M="$(nmcli -g ipv6.method connection show "$C")"
      if [ "$M" = "auto" ] ; then
         echo "Disabling IPv6 on $C (was $M)"
         sudo nmcli connection modify "$C" ipv6.method "ignore"
      fi
   done

   # add hook script if it exists
   try_merge "/etc/NetworkManager/dispatcher.d" "adding sysctl hook script"

   # apply local customisations
   if SOURCE="$(supporting_file "/etc/NetworkManager/custom_settings.sh")" ; then
      if [ -f "$SOURCE" -a -x "$SOURCE" ] ; then
         "$SOURCE"
      else
         echo "Warning: $SOURCE skipped (needs execute permission)"
      fi
   fi

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

# patching dphys-swapfile is deprecated
if PATCH="$(supporting_file "/etc/dphys-swapfile.patch")" ; then
   echo "[DEPRECATION] $PATCH is deprecated. Forcing VM_SWAP=default"
   echo "              Please see PiBuilder documentation on try_edit()"
   VM_SWAP="default"
fi

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
         if try_edit "/etc/dphys-swapfile" "setting swap to max(2*physRAM,2048) GB" ; then

            # patch success! deploy
            sudo dphys-swapfile setup

         fi

         # re-enable swap (reboot occurrs soon)
         sudo dphys-swapfile swapon

      fi
      ;;

   "custom" )

      # try to patch the swap file setup
      if try_edit "/etc/dphys-swapfile" "setting custom swap" ; then

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
