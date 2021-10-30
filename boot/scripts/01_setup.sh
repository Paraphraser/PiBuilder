#!/usr/bin/env bash

# user options
LOCALCC="AU"
LOCALTZ="Australia/Sydney"

# should not run as root
[ "$EUID" -eq 0 ] && echo "This script should NOT be run using sudo" && exit -1

# the name of this script is
SCRIPT=$(basename "$0")

case "$#" in

  1)
    MACHINE_NAME="$1"
    read -s -p "Password for $USER@$MACHINE_NAME: " NEW_PASSWORD
    echo ""
    ;;

  2)
    MACHINE_NAME="$1"
    NEW_PASSWORD="$2"
    ;;

  *)
    echo "Usage: $SCRIPT machinename {password}"
    echo "       (will prompt for password if omitted)"
    exit -1
    ;;

esac

# declare path to support directory
SUPPORT="/boot/scripts/support"

echo "Initialising empty user directories for SSH and GnuPG"
[ ! -d "$HOME/.gnupg" ] && mkdir -p "$HOME/.gnupg"
[ ! -d "$HOME/.ssh" ] && mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.gnupg" "$HOME/.ssh"

echo "Adding Debian Buster Backports support (for libseccomp2)"
sudo apt-key adv \
   --keyserver hkps://keyserver.ubuntu.com:443 \
   --recv-keys 04EE7237B7D453EC 648ACFD622F3D138
SOURCE="$SUPPORT/debian-backports.list"
TARGET="/etc/apt/sources.list.d/debian-backports.list"
cat "$SOURCE" | sudo tee -a "$TARGET" >/dev/null

echo "Running sudo apt update"
sudo apt update

echo "Running sudo apt full-upgrade -y"
sudo apt full-upgrade -y
sudo apt autoremove -y

# copy etc
echo "Taking a baseline copy of /etc"
sudo cp -a /etc /etc-baseline

# if there is a preset for /etc/ssh, it will be at the path
SSH_PRESET="$SUPPORT/$MACHINE_NAME.etc-ssh-backup.tar.gz"

# does the preset exist?
if [ -e "$SSH_PRESET" ] ; then

   # yes! replace /etc/ssh
   echo "Replacing /etc/ssh with $SSH_PRESET"
   cd /etc
   sudo mv ssh ssh.old
   sudo mkdir ssh
   sudo chown root:root ssh
   sudo chmod 755 ssh
   cd ssh
   sudo tar --same-owner -xzf "$SSH_PRESET"

else

   # no! alert
   echo "$SSH_PRESET not found - /etc/ssh is as set by Raspbian"
   
fi

# remove all ssh presets from boot volume
sudo rm $SUPPORT/*.etc-ssh-backup.tar.gz

# change the login password
echo "Setting the user password"
echo -e "$NEW_PASSWORD\n$NEW_PASSWORD" | sudo passwd $USER

# make the VNC password the same
VNCSOURCE="$SUPPORT/common.custom"
VNCTARGET="/etc/vnc/config.d/common.custom"
if [ -e "$VNCSOURCE" ] ; then
   echo "Setting up VNC (even though it is not activated)"
   sudo cp "$VNCSOURCE" "$VNCTARGET"
   echo -e "$NEW_PASSWORD\n$NEW_PASSWORD" | sudo vncpasswd -file "$VNCTARGET"
   sudo chown root:root "$VNCTARGET"
   sudo chmod 644 "$VNCTARGET"
fi

# copy locale edits to a file in RAM
LOCALE_EDITS="$(mktemp -p /dev/shm/)"
cat <<-LOCALE_EDITS >"$LOCALE_EDITS"
s/^#.*en_AU ISO-8859-1/en_AU ISO-8859-1/
s/^#.*en_AU.UTF-8 UTF-8/en_AU.UTF-8 UTF-8/
s/^en_GB.UTF-8 UTF-8/# en_GB.UTF-8 UTF-8/
s/^#.*en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/
LOCALE_EDITS

echo "Setting locales (ignore errors)"
sudo sed -i.bak -f "$LOCALE_EDITS" /etc/locale.gen
sudo locale-gen
# this produces an error - but it seems to work anyway (after reboot)
sudo update-locale LANG=en_US.UTF-8

# boot to console (no desktop GUI)
# hints from https://discord.com/channels/638610460567928832/638610461109256194/792694778613202966
echo "Setting boot behaviour to console (no GUI)"
sudo raspi-config nonint do_boot_behaviour B1

echo "Setting WiFi country code to $LOCALCC"
sudo raspi-config nonint do_wifi_country "$LOCALCC"

echo "Setting time-zone to $LOCALTZ"
sudo raspi-config nonint do_change_timezone "$LOCALTZ"

# set the host name (do this LAST - produces errors)
echo "Setting machine name to $MACHINE_NAME"
sudo raspi-config nonint do_hostname "$MACHINE_NAME"

echo "Remember to do ssh-keygen -R raspberrypi.local then re-connect"
echo "to this machine under the name $MACHINE_NAME."
echo "$SCRIPT complete - rebooting..."
sudo reboot
