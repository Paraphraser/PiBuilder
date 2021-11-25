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

if $(is_running_raspbian buster) ; then
   echo "Installing updated libseccomp2 (for Alpine images)"
   sudo apt install libseccomp2 -t buster-backports
fi

echo "Installing additional packages"
PACKAGES="$(mktemp -p /dev/shm/)"
cat <<-BASE_PACKAGES >"$PACKAGES"
acl
curl
bridge-utils
dnsutils
git
iotop
iperf
jq
libffi-dev
libreadline-dev
mosquitto-clients
nmap
python3-pip
python3-dev
rlwrap
ruby
sqlite3
sshfs
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
python3-gnupg
rng-tools
scdaemon
secure-delete
yubikey-personalization
CRYPTO_PACKAGES

install_packages "$PACKAGES"

echo "Making python3 the default"
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 1

if try_patch "/etc/systemd/timesyncd.conf" "local time-servers" ; then
   sudo timedatectl set-ntp false
   sudo timedatectl set-ntp true
   timedatectl show-timesync
fi

TARGET="/etc/udev/rules.d"
if SOURCE="$(supporting_file "$TARGET")" ; then
   echo "Adding USB device rules"
   sudo cp -n "$SOURCE"/* "$TARGET"
   sudo chown root:root "$TARGET"/*
   sudo chmod 644 "$TARGET"/*
fi

# create $HOME/.profile
TARGET="$HOME/.profile"
if SOURCE="$(supporting_file "$TARGET")" ; then
   echo "Creating .profile from $SOURCE"
   cp "$SOURCE" "$TARGET"
fi

# create a crontab
if SOURCE="$(supporting_file "$HOME/crontab")" ; then
   echo "Setting up crontab from $SOURCE"
   mkdir ~/Logs
   crontab "$SOURCE"
fi

# guarantee ~/.local/bin exists
TARGET="$HOME/.local/bin"
echo "Initialising $TARGET"
mkdir -p "$TARGET"

echo "Cloning IOTstack"
git clone https://github.com/SensorsIot/IOTstack.git ~/IOTstack 

echo "Cloning IOTstackAliases"
git clone https://github.com/Paraphraser/IOTstackAliases.git ~/.local/IOTstackAliases

echo "Installing rclone and shell yaml support"
curl https://rclone.org/install.sh | sudo bash
sudo pip3 install -U niet

echo "Cloning and installing IOTstackBackup"
git clone https://github.com/Paraphraser/IOTstackBackup.git ~/.local/IOTstackBackup
~/.local/IOTstackBackup/install_scripts.sh

TARGET="$HOME/.config/rclone/rclone.conf"
if SOURCE="$(supporting_file "$TARGET")" ; then
   echo "Installing configuration file for rclone from $SOURCE"
   mkdir -p $(dirname $TARGET)
   cp "$SOURCE" "$TARGET"
fi

TARGET="$HOME/.config/iotstack_backup/config.yml"
if SOURCE="$(supporting_file "$TARGET")" ; then
   echo "Installing configuration file for iotstack_backup from $SOURCE"
   mkdir -p $(dirname $TARGET)
   cp "$SOURCE" "$TARGET"
fi

# run the script epilog if it exists
run_pibuilder_epilog

# kill the parent process
echo "$SCRIPT complete. Logging-out..."
kill -HUP "$PPID"
