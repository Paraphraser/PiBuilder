#!/usr/bin/env bash

# should not run as root
[ "$EUID" -eq 0 ] && echo "This script should NOT be run using sudo" && exit -1

# the name of this script is
SCRIPT=$(basename "$0")

if [ "$#" -gt 0 ]; then
    echo "Usage: $SCRIPT"
    exit -1
fi

SUPPORT="/boot/scripts/support"

echo "Installing additional packages"
# remember: ONE AT A TIME (so a failure of one doesn't stuff others)
sudo apt install -y acl
sudo apt install -y curl
sudo apt install -y dnsutils
sudo apt install -y git
sudo apt install -y iotop
sudo apt install -y iperf
sudo apt install -y jq
sudo apt install -y libreadline-dev
sudo apt install -y mosquitto-clients
sudo apt install -y nmap
sudo apt install -y rlwrap
sudo apt install -y ruby
sudo apt install -y sqlite3
sudo apt install -y subversion
sudo apt install -y sysstat
sudo apt install -y tcpdump
sudo apt install -y time
sudo apt install -y uuid-runtime
sudo apt install -y wget


echo "Installing additional packages for YubiKey"
sudo apt install -y at
sudo apt install -y cryptsetup
sudo apt install -y dirmngr
sudo apt install -y gnupg-agent
sudo apt install -y gnupg2
sudo apt install -y hopenpgp-tools
sudo apt install -y openssl
sudo apt install -y pcscd
sudo apt install -y python-gnupg
sudo apt install -y rng-tools
sudo apt install -y scdaemon
sudo apt install -y secure-delete
sudo apt install -y yubikey-personalization

SOURCE="/etc/systemd/timesyncd.conf"
PATCH="$SUPPORT/timesyncd.conf.patch"
MATCH="^\[Time\]"
if [ $(egrep -c "$MATCH" "$SOURCE") -eq 1 ] ; then
   echo "Patching /etc/systemd/timesyncd.conf to add local time-servers"
   sudo sed -i.bak "/$MATCH/r $PATCH" "$SOURCE"
   sudo timedatectl set-ntp false
   sudo timedatectl set-ntp true
   timedatectl show-timesync
else
   echo "Warning: could not patch $SOURCE"
   sleep 5
fi

echo "Adding known USB devices"
sudo cp "$SUPPORT/99-usb-serial.rules" "/etc/udev/rules.d/"
sudo chown root:root "/etc/udev/rules.d/99-usb-serial.rules"
sudo chmod 644 "/etc/udev/rules.d/99-usb-serial.rules"

echo "Setting up ~/.local/bin"
mkdir -p ~/.local
#
# the way I do this is to "svn checkout" from a local subversion server
# you will need to come up with some mechanism of your own to get any
# scripts or binaries installed that are part of your standard install
#

echo "Creating .profile"
cp $SUPPORT/User.profile ~/.profile

echo "Setting up crontab"
mkdir ~/Logs
crontab $SUPPORT/User.crontab

echo "Cloning IOTstack old menu"
git clone -b old-menu https://github.com/SensorsIot/IOTstack.git ~/IOTstack 

echo "Mimicking old-menu installation of docker and docker-compose"
curl -fsSL https://get.docker.com | sh
sudo usermod -G docker -a $USER
sudo usermod -G bluetooth -a $USER
sudo apt install -y python3-pip python3-dev
sudo pip3 install -U docker-compose
sudo pip3 install -U ruamel.yaml==0.16.12 blessed

echo "Cloning IOTstackAliases"
git clone https://github.com/Paraphraser/IOTstackAliases.git ~/.local/IOTstackAliases

echo "Installing rclone and shell yaml support"
curl https://rclone.org/install.sh | sudo bash
sudo pip3 install -U niet

echo "Cloning and installing IOTstackBackup"
git clone https://github.com/Paraphraser/IOTstackBackup.git ~/.local/IOTstackBackup
~/.local/IOTstackBackup/install_scripts.sh

SOURCE="$SUPPORT/rclone.conf"
TARGET_DIR="$HOME/.config/rclone"
TARGET="rclone.conf"
if [ -e "$SOURCE" ] ; then
   echo "Installing configuration file for rclone"
   mkdir -p "$TARGET_DIR"
   cp "$SOURCE" "$TARGET_DIR/$TARGET"
fi

SOURCE="$SUPPORT/iotstack_backup-config.yml"
TARGET_DIR="$HOME/.config/iotstack_backup"
TARGET="config.yml"
if [ -e "$SOURCE" ] ; then
   echo "Installing configuration file for iotstack_backup"
   mkdir -p "$TARGET_DIR"
   cp "$SOURCE" "$TARGET_DIR/$TARGET"
fi

echo "$SCRIPT complete. Rebooting..."
sudo reboot
