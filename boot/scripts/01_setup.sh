#!/usr/bin/env bash

# should not run as root
[ "$EUID" -eq 0 ] && echo "This script should NOT be run using sudo" && exit 1

# the name of this script is
SCRIPT=$(basename "$0")

# where is this script is running?
WHERE=$(dirname "$(realpath "$0")")

# assume ssh trust does not need to be reset on the support host
WARN_TRUST_RESET="false"

# note the current hostname
SAVE_HOSTNAME="$HOSTNAME"

# allow an optional argument to overwrite the hostname
# HOSTNAME needs to be set here so @syntax works in this script
HOSTNAME="${1:-"$HOSTNAME"}"

# declare path to support and helper directories
SUPPORT="$WHERE/support"
HELPERS="$WHERE/helpers"

# import common functions
. "$SUPPORT/pibuilder/functions.sh"

# copy etc
echo "Taking a baseline copy of /etc"
sudo cp -a /etc /etc-baseline

# copy important files in /boot
for TARGET in cmdline.txt config.txt ; do
   CANDIDATE=$(path_to_pi_boot_file "$TARGET")
   if [ -e "$CANDIDATE" ] ; then
      echo "Taking baseline copy of $CANDIDATE"
      sudo cp "$CANDIDATE" "$CANDIDATE.baseline"
   fi
done

# import user options and run the script prolog - if they exist
run_pibuilder_prolog

echo "Initialising empty user directories for SSH, GnuPG, etc"
[ ! -d "$HOME/.gnupg" ] && mkdir -p "$HOME/.gnupg"
[ ! -d "$HOME/.ssh" ] && mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.gnupg" "$HOME/.ssh"
[ ! -d "$HOME/.local/bin" ] && mkdir -p "$HOME/.local/bin"

# backports support for libseccomp2 (64-bit date/time) in buster
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

# is this a debian distribution?
if is_running_OS_distro debian ; then
   # yes! the default is a full upgrade
   SKIP_FULL_UPGRADE="${SKIP_FULL_UPGRADE:-"false"}"
else
   # no! the default is a routine upgrade
   SKIP_FULL_UPGRADE="${SKIP_FULL_UPGRADE:-"true"}"
fi

# run the appropriate update
if [ "$SKIP_FULL_UPGRADE" = "true" ] ; then
   echo "Running sudo apt upgrade -y"
   sudo apt upgrade -y
else
   echo "Running sudo apt full-upgrade -y"
   sudo apt full-upgrade -y
fi

# ensure basics available on non-Raspbian systems
echo "Satisfying PiBuilder dependencies"
sudo apt install -y git rsync avahi-daemon

# remove any junk so we don't get reminders
sudo apt autoremove -y

# apply any preset for /etc/ssh
if SOURCE="$(supporting_file "/etc/ssh/etc-ssh-backup.tar.gz")" ; then

   # yes! replace /etc/ssh
   echo "Replacing /etc/ssh with $SOURCE"
   sudo mv /etc/ssh /etc/ssh.old
   sudo mkdir /etc/ssh
   sudo chown root:root /etc/ssh
   sudo chmod 755 /etc/ssh
   sudo tar --same-owner -xzf "$SOURCE" -C /etc/ssh
   sudo systemctl restart sshd ssh
   WARN_TRUST_RESET="true"

else

   # no! alert
   echo "$SOURCE not found - /etc/ssh is as set by Raspbian"
   
fi

# is this script running from /boot ?
if [[ "$WHERE" == "/boot/"* ]] ; then

   # yes! remove all ssh presets from boot volume
   echo "Removing all /etc/ssh presets"
   sudo rm -rf $SUPPORT/etc/ssh

fi

if is_raspberry_pi ; then

   # see if 64-bit kernel should be enabled
   TARGET=$(path_to_pi_boot_file "config.txt")
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

      "bullseye+legacy" ) ;&
      "bookworm+legacy" )
         echo "Enabling Raspberry Pi ribbon-cable camera in legacy mode"
         sudo raspi-config nonint do_legacy 0
         ;;

      "bullseye+true" ) ;&
      "bookworm+true" )
         echo "Enabling Raspberry Pi ribbon-cable camera"
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

   # has the user given permission for an EEPROM upgrade?
   if [ "$SKIP_EEPROM_UPGRADE" != "true" ] ; then

      # yes! is an upgrade available?
      if [ $(sudo rpi-eeprom-update | grep -c "*** UPDATE AVAILABLE ***") -gt 0 ] ; then

         # yes! proceed
         echo "Updating Raspberry Pi Firmware"
         sudo rpi-eeprom-update -d -a
         echo "Note: the next reboot may take a little longer than expected"

      else
   
         # no! advise
         echo "Note: Raspberry Pi Firmware is up-to-date"

      fi

   fi

else

   echo "PiBuilder appears to be running on non-Raspberry Pi OS !"

   echo "The following PiBuilder options have been ignored:"
   echo "   ENABLE_PI_CAMERA"
   [ "$PREFER_64BIT_KERNEL" = "true" ] && echo "   PREFER_64BIT_KERNEL"
   [ "$SKIP_EEPROM_UPGRADE" = "false" ] && echo "   SKIP_EEPROM_UPGRADE"

   # run the script epilog if it exists
   run_pibuilder_epilog

   echo "Setting boot behaviour to console (no GUI)"
   sudo systemctl --quiet set-default multi-user.target

fi

# set the hostname. set_hostname.sh:
# 1. sanitises any proposed "#03626F"; and also attempts to
# 2. set a proper domain name.
sudo $HELPERS/set_hostname.sh "$HOSTNAME"

# acquire actual hostname now in force (may have been sanitised)
HOSTNAME="$(hostname -s)"

# sense change of hostname
[ "$HOSTNAME" != "$SAVE_HOSTNAME" ] && WARN_TRUST_RESET="true"

# has anything been done to invalidate known_hosts on the support host?
if [ "$WARN_TRUST_RESET" = "true" ] ; then

   # maybe - advise accordingly
   echo "Remember to do ssh-keygen -R $SAVE_HOSTNAME.local"
   echo "Reconnect using ssh $USER@$HOSTNAME.local"

fi

echo "$SCRIPT complete - rebooting..."

echo "If the Raspberry Pi does not seem to reboot cleanly, it is OK to remove"
echo "and re-apply power. A normal reboot takes about 30-40 seconds. A good"
echo "test of whether the Pi has hung is if you can 'ping' the Pi but ssh says"
echo "'Connection refused' when you try to connect."

sudo touch /boot/ssh
sudo /usr/sbin/reboot
