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

# canned general advisory if IOTstack already exists
read -r -d "\n" IOTSTACKFAIL <<-EOM
========================================================================
The $HOME/IOTstack directory already exists. This script needs to
clone IOTstack from GitHub but git won't clone into a directory that
already exists. You should EITHER rename the existing folder:

   mv ~/IOTstack ~/IOTstack.off

OR delete the existing folder:

   sudo rm -rf ~/IOTstack

and then re-run this script.
========================================================================
EOM

# sense IOTstack folder already exists
if [ -d "$HOME/IOTstack" ] ; then
   echo "$IOTSTACKFAIL"
   exit 1
fi

# ensure apt caches are up-to-date (protects against any significant
# delay between running this script and the 01 script)
sudo apt update

if is_running_OS_release buster ; then
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
netcat-openbsd
nmap
python3-pip
python3-dev
python3-virtualenv
rlwrap
ruby
software-properties-common
sqlite3
sshfs
subversion
sysstat
tcpdump
time
traceroute
tree
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
yubikey-manager
yubikey-personalization
CRYPTO_PACKAGES


# python3-ykman is not available on buster
if ! is_running_OS_release buster ; then
   echo "python3-ykman" >>"$PACKAGES"
fi

install_packages "$PACKAGES"

# 02 disables IPv6 but exim4 is only installed as a by-product of
# installing "at" - apply the fix here
try_patch "/etc/exim4/update-exim4.conf.conf" "stop exim4 paniclog messages (when IPv6 disabled)"

# samba support
TARGET="/etc/samba/smb.conf"
if SOURCE="$(supporting_file "$TARGET")" ; then
   echo "Adding SAMBA support"
   # install dependencies (samba includes samba-common samba-common-bin)
   sudo apt install -y samba smbclient
   # replace smb.conf
   sudo cp "$SOURCE" "$TARGET"
   sudo chown root:root "$TARGET"
   sudo chmod 644 "$TARGET"
   # optional replacement of passwords and secrets
   for C in "passdb.tdb" "secrets.tdb" ; do
      T="/var/lib/samba/private/$C"
      if S="$(supporting_file "$T")" ; then
         sudo cp "$S" "$T"
         sudo chown root:root "$T"
         sudo chmod 600 "$T"
      fi
   done
   mkdir -p "$HOME/share"
   echo "Restarting SAMBA daemon"
   sudo service smbd restart
fi

echo "Making python3 the default"
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 1

if try_patch "/etc/systemd/timesyncd.conf" "local time-servers" ; then
   sudo timedatectl set-ntp false
   sudo timedatectl set-ntp true
   timedatectl show-timesync
fi

TARGET="/etc/udev/rules.d"
if try_merge "$TARGET" "USB device rules" ; then
   sudo chown root:root "$TARGET"/*
   sudo chmod 644 "$TARGET"/*
fi

echo "Cloning IOTstack"
git clone https://github.com/SensorsIot/IOTstack.git ~/IOTstack

# by definition a clean install is up-to-date but the menu chucks up
# inappropriate and, IMV, quite misleading alert about a large update,
# breaking changes, and an invitation to switch to old-menu where the
# default is "yes". That can be very confusing for first-time users so
# this next line bypasses that alert:
touch "$HOME/IOTstack/.new_install"

echo "Protective creation of sub-folders which should be user-owned"
mkdir -p "$HOME/IOTstack/backups" "$HOME/IOTstack/services"

# I will put in a pull request to remove pins from the requirements
# files in the IOTstack directory. For now, this hack serves the
# same purpose
if is_running_OS_release bookworm ; then
   echo "Removing pins from IOTstack Python requirements files"
   sed -i.bak 's/==.*//' \
      "$HOME/IOTstack/requirements-menu.txt" \
      "$HOME/IOTstack/requirements-mkdocs.txt"
fi

echo "Cloning IOTstackAliases"
git clone https://github.com/Paraphraser/IOTstackAliases.git ~/.local/IOTstackAliases

echo "Installing rclone and shell yaml support"
curl https://rclone.org/install.sh | sudo bash
pip3 install -U $PIBUILDER_PYTHON_OPTIONS shyaml

echo "Cloning and installing IOTstackBackup"
git clone https://github.com/Paraphraser/IOTstackBackup.git ~/.local/IOTstackBackup
~/.local/IOTstackBackup/install_scripts.sh

TARGET="$HOME/IOTstack/requirements-mkdocs.txt"
if [ -e "$TARGET" ] ; then
   echo "Adding mkdocs support (eg mkdocs serve -a 0.0.0.0:8765)" 
   pip3 install $PIBUILDER_PYTHON_OPTIONS -r "$TARGET"
fi

# run the script epilog if it exists
run_pibuilder_epilog

# kill the parent process
echo "$SCRIPT complete. Logging-out..."
kill -HUP "$PPID"
