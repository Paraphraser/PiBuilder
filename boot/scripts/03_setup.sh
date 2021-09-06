#!/usr/bin/env bash

# should not run as root
[ "$EUID" -eq 0 ] && echo "This script should NOT be run using sudo" && exit -1

# the name of this script is
SCRIPT=$(basename "$0")

if [ "$#" -gt 0 ]; then
    echo "Usage: $SCRIPT"
    exit -1
fi

# assume supervised home assistant not to be installed
HASSIO_ARCHITECTURE=""

# if you want supervised home assistant, uncomment ONE of the following
#HASSIO_ARCHITECTURE="raspberrypi4-64"
#HASSIO_ARCHITECTURE="raspberrypi4"
#HASSIO_ARCHITECTURE="raspberrypi3-64"
#HASSIO_ARCHITECTURE="raspberrypi3"

SUPPORT="/boot/scripts/support"

# a function to handle installation of a list of packages done ONE AT
# A TIME to reduce failure problems resulting from the all-too-frequent
#  Failed to fetch http://raspbian.raspberrypi.org/raspbian/pool/main/z/zip/zip_3.0-11_armhf.deb
#   Unable to connect to raspbian.raspberrypi.org:http: [IP: 93.93.128.193 80]

install_packages() {

   # declare nothing to retry
   unset RETRIES
   
   # iterate the contents of the file argument
   for PACKAGE in $(cat "$1") ; do

      # attempt to install the package
      sudo apt install -y "$PACKAGE"

      # did the installation succeed or is something playing up?
      if [ $? -ne 0 ] ; then

         # the installation failed - does a retry list exist?
         if [ -z "$RETRIES" ] ; then

            # no! create the file
            RETRIES="$(mktemp -p /dev/shm/)"

         fi

         # add a manual retry
         echo "sudo apt install -y $PACKAGE" >>"$RETRIES"

         # report the event
         echo "PACKAGE INSTALL FAILURE - retry $PACKAGE by hand"

      fi

   done

   # any retries?
   if [ ! -z "$RETRIES" ] ; then

      # yes! bung out the list
      echo "Some base packages could not be installed. This is usually"
      echo "because of some transient problem with APT."
      echo "Retry the errant installations listed below by hand, and"
      echo "then re-run $SCRIPT"
      cat "$RETRIES"
      exit -1

   fi

}

echo "Installing updated libseccomp2 (for Alpine images)"
sudo apt install libseccomp2 -t buster-backports

echo "Installing additional packages"
PACKAGES="$(mktemp -p /dev/shm/)"
cat <<-BASE_PACKAGES >"$PACKAGES"
acl
curl
dnsutils
git
iotop
iperf
jq
libreadline-dev
mosquitto-clients
nmap
rlwrap
ruby
sqlite3
subversion
sysstat
tcpdump
time
uuid-runtime
wget
BASE_PACKAGES

install_packages "$PACKAGES"

cat <<-CRYPTO_PACKAGES >"$PACKAGES"
at
cryptsetup
dirmngr
gnupg-agent
gnupg2
hopenpgp-tools
openssl
pcscd
python-gnupg
rng-tools
scdaemon
secure-delete
yubikey-personalization
CRYPTO_PACKAGES

install_packages "$PACKAGES"

cat <<-HASSIO_PACKAGES >"$PACKAGES"
apparmor
apparmor-profiles
apparmor-utils
software-properties-common
apt-transport-https
ca-certificates
dbus
avahi-daemon
network-manager
HASSIO_PACKAGES

if [ -n "$HASSIO_ARCHITECTURE" ] ; then
   install_packages "$PACKAGES"
fi

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

echo "Adding USB device rules"
SOURCE="$SUPPORT/udev-rules"
TARGET_DIR="/etc/udev/rules.d"
for RULE in "$SOURCE"/* ; do
   TARGET="$TARGET_DIR/$(basename "$RULE")"
   sudo cp "$RULE" "$TARGET"
   sudo chown root:root "$TARGET"
   sudo chmod 644 "$TARGET"
done

echo "Setting up ~/.local/bin"
mkdir -p ~/.local/bin
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

echo "Cloning IOTstack"
git clone https://github.com/SensorsIot/IOTstack.git ~/IOTstack 

echo "Installing docker and docker-compose"
curl -fsSL https://get.docker.com | sh
sudo usermod -G docker -a $USER
sudo usermod -G bluetooth -a $USER
sudo apt install -y python3-pip python3-dev
[ "$(uname -m)" = "aarch64" ] && sudo apt install libffi-dev
sudo pip3 install -U docker-compose
sudo pip3 install -U ruamel.yaml==0.16.12 blessed

echo "Making python3 the default"
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 1

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

if [ -n "$HASSIO_ARCHITECTURE" ] ; then

   echo -e "\n\n\n\n"
   echo "=============================================================="
   echo "Installing hass.io - note that this WILL stop this script"
   echo "from completing automatically because you WILL be required"
   echo "to respond to a prompt."
   echo "=============================================================="
   echo -e "\n\n\n\n"

   sudo systemctl disable ModemManager
   sudo systemctl stop ModemManager
   curl -sL "https://raw.githubusercontent.com/Kanga-Who/home-assistant/master/supervised-installer.sh" | sudo bash -s -- -m "$HASSIO_ARCHITECTURE"

   echo "Disabling Network Manager random Wifi MAC"
   SOURCE="$SUPPORT/NetworkManager.conf.patch"
   TARGET="/etc/NetworkManager/NetworkManager.conf"
   cat "$SOURCE" | sudo tee -a "$TARGET" >/dev/null
   sudo systemctl restart NetworkManager.service

fi

echo "$SCRIPT complete. Rebooting..."
sudo reboot
