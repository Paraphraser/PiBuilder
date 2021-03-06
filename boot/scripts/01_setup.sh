#!/usr/bin/env bash

# should not run as root
[ "$EUID" -eq 0 ] && echo "This script should NOT be run using sudo" && exit -1

# the name of this script is
SCRIPT=$(basename "$0")

# where is this script is running?
WHERE=$(dirname "$(realpath "$0")")

# assume ssh trust does not need to be reset on the support host
WARN_TRUST_RESET="false"

# note the current hostname
SAVE_HOSTNAME="$HOSTNAME"

# allow an optional argument to overwrite the hostname
HOSTNAME="${1:-"$HOSTNAME"}"

# declare path to support directory and import common functions
SUPPORT="$WHERE/support"
. "$SUPPORT/pibuilder/functions.sh"

# copy etc
echo "Taking a baseline copy of /etc"
sudo cp -a /etc /etc-baseline

# copy important files in /boot
echo "Taking baseline copies of cmdline.txt and config.txt"
sudo cp /boot/cmdline.txt /boot/cmdline.txt.baseline
sudo cp /boot/config.txt /boot/config.txt.baseline

# import user options and run the script prolog - if they exist
run_pibuilder_prolog

echo "Initialising empty user directories for SSH, GnuPG, etc"
[ ! -d "$HOME/.gnupg" ] && mkdir -p "$HOME/.gnupg"
[ ! -d "$HOME/.ssh" ] && mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.gnupg" "$HOME/.ssh"
[ ! -d "$HOME/.local/bin" ] && mkdir -p "$HOME/.local/bin"

if is_running_OS_release buster ; then
   echo "Adding Debian Buster Backports support (for libseccomp2)"
   sudo apt-key adv \
      --keyserver hkps://keyserver.ubuntu.com:443 \
      --recv-keys 04EE7237B7D453EC 648ACFD622F3D138
   TARGET="/etc/apt/sources.list.d/debian-backports.list"
   if SOURCE="$(supporting_file "$TARGET")" ; then
      cat "$SOURCE" | sudo tee -a "$TARGET" >/dev/null
   fi
fi

echo "Running sudo apt update"
sudo apt update

if [ "$SKIP_FULL_UPGRADE" = "false" ] ; then
   echo "Running sudo apt full-upgrade -y"
   sudo apt full-upgrade -y
   sudo apt autoremove -y
fi

# apply any preset for /etc/ssh
if SOURCE="$(supporting_file "/etc/ssh/etc-ssh-backup.tar.gz")" ; then

   # yes! replace /etc/ssh
   echo "Replacing /etc/ssh with $SOURCE"
   sudo mv /etc/ssh /etc/ssh.old
   sudo mkdir /etc/ssh
   sudo chown root:root /etc/ssh
   sudo chmod 755 /etc/ssh
   sudo tar --same-owner -xzf "$SOURCE" -C /etc/ssh
   WARN_TRUST_RESET="true"

else

   # no! alert
   echo "$SOURCE not found - /etc/ssh is as set by Raspbian"
   
fi

# remove all ssh presets from boot volume
echo "Removing all /etc/ssh presets"
sudo rm -rf $SUPPORT/etc/ssh

# see if 64-bit kernel should be enabled
TARGET="/boot/config.txt"
APPEND="arm_64bit=1"
# is the kernel already 64-bit?
if [ ! "$(uname -m)" = "aarch64" ] ; then
  # no! is the 64-bit kernel preferred?
  if [ "$PREFER_64BIT_KERNEL" = "true" ] ; then
     echo "Enabling 64-bit kernel"
     sudo sed -i.bak "$ a $APPEND" "$TARGET"
  fi
fi

# see if Raspberry Pi ribbon-cable camera should be enabled
case "$(running_OS_release)+$ENABLE_PI_CAMERA" in

   "buster+legacy" ) ;&
   "buster+true" )
      echo "Enabling Raspberry Pi ribbon-cable camera"
      sudo raspi-config nonint do_camera 0
      ;;

   "bullseye+legacy" )
      echo "Enabling Raspberry Pi ribbon-cable camera in legacy mode"
      sudo raspi-config nonint do_legacy 0
      ;;

   "bullseye+true" )
      echo "Enabling Raspberry Pi ribbon-cable camera in bullseye mode"
      sudo raspi-config nonint do_camera 0
      ;;

   *)
      echo "Raspberry Pi ribbon-cable camera not enabled"
      ;;

esac

# run the script epilog if it exists (best to run before rasp-config)
run_pibuilder_epilog

# boot to console (no desktop GUI)
# hints from https://discord.com/channels/638610460567928832/638610461109256194/792694778613202966
echo "Setting boot behaviour to console (no GUI)"
sudo raspi-config nonint do_boot_behaviour B1

# set/override WiFi country code as an option
if [ -n "$LOCALCC" ] ; then
   echo "Setting WiFi country code to $LOCALCC"
   sudo raspi-config nonint do_wifi_country "$LOCALCC"
fi

# set timezone if provided and what is in effect are different
if [ -n "$LOCALTZ" -a "$LOCALTZ" != "$(cat /etc/timezone)" ] ; then 
   echo "Setting time-zone to $LOCALTZ"
   sudo raspi-config nonint do_change_timezone "$LOCALTZ"
fi

# try to establish locales - seems best to do this last. Note the patch
# should always retain "en_GB.UTF-8" so we don't pull the rug out from
# beneath anything (like Python) that already knows the default language
# (it can be removed later if need be, eg using raspi-config.
if try_patch "/etc/locale.gen" "setting locales (ignore errors)" ; then
   sudo dpkg-reconfigure -f noninteractive locales
fi

# does the host name need to be updated?
if [ "$HOSTNAME" != "$SAVE_HOSTNAME" ] ; then

   # yes! set the host name (produces errors)
   echo "Setting machine name to $HOSTNAME"
   sudo raspi-config nonint do_hostname "$HOSTNAME"
   WARN_TRUST_RESET="true"

fi

# has anything been done to invalidate known_hosts on the support host?
if [ "$WARN_TRUST_RESET" = "true" ] ; then

   # maybe - advise accordingly
   echo "Remember to do ssh-keygen -R $SAVE_HOSTNAME.local"
   echo "Reconnect using ssh $USER@$HOSTNAME.local"

fi

echo "$SCRIPT complete - rebooting..."
sudo touch /boot/ssh
sudo reboot
