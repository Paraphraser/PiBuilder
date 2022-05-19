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

# add these to /boot/cmdline.txt
CMDLINE_OPTIONS="cgroup_memory=1 cgroup_enable=memory"

# canned general advisory if docker install script returns an error
read -r -d '' DOCKERFAIL <<-EOM
========================================================================
The docker installation script stopped because of an error. This is not
a problem in the PiBuilder $SCRIPT script. It is a problem in the script
supplied by Docker that is downloaded from https://get.docker.com. You
will need to examine the output above to determine why the installation
failed. Best case is that the problem is transient so waiting a while
and re-running $SCRIPT might let you proceed. Worst case is that the
problem is persistent which MAY indicate that the cause is something
about your networking arrangements or your ISP.
========================================================================
EOM

# install Docker
echo "Installing docker"
curl -fsSL https://get.docker.com | sudo sh
if [ $? -ne 0 ] ; then
   echo "$DOCKERFAIL"
   exit 1
fi

echo "Setting groups required for docker and bluetooth"
sudo usermod -G docker -a $USER
sudo usermod -G bluetooth -a $USER

echo "Installing docker-compose"

# apply defaults for docker-compose (can be overridden in options.sh)
# https://github.com/docker/compose/releases
DOCKER_COMPOSE_VERSION="${DOCKER_COMPOSE_VERSION:-"v2.5.1"}"
if is_running_OS_64bit ; then
   DOCKER_COMPOSE_ARCHITECTURE="${DOCKER_COMPOSE_ARCHITECTURE:-"aarch64"}"
else
   DOCKER_COMPOSE_ARCHITECTURE="${DOCKER_COMPOSE_ARCHITECTURE:-"armv7"}"
fi

# construct the URL
COMPOSE_URL="https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-linux-$DOCKER_COMPOSE_ARCHITECTURE"

# download defaults to user-space
PLUGINS="$HOME/.docker/cli-plugins"

# where sudo is not required
unset SUDO

# iterate system-wide candidates
for CANDIDATE in \
  "/usr/libexec/docker/cli-plugins" \
  "/usr/local/libexec/docker/cli-plugins" \
  "/usr/lib/docker/cli-plugins" \
  "/usr/local/lib/docker/cli-plugins"
do
  if [ -d "$CANDIDATE" ] ; then
     PLUGINS="$CANDIDATE"
     SUDO="sudo"
     break
  fi
done

# ensure the download directory exists
$SUDO mkdir -p "$PLUGINS"

# the target is
TARGET="$PLUGINS/docker-compose"

# try to fetch
$SUDO wget -q "$COMPOSE_URL" -O "$TARGET"

# did the download succeed?
if [ $? -eq 0 ] ; then

   # yes! set execute permission on the target
   $SUDO chmod +x "$TARGET"

   # and also copy to /usr/local/bin/ (sudo always required)
   sudo cp "$TARGET" "/usr/local/bin/"

   # yes! report success
   echo "Modern docker-compose installed as $TARGET - also copied to /usr/local/bin/"

else

   # no! failed. That means TARGET is useless
   $SUDO rm -f "$TARGET"

   echo "Attempt to download docker-compose failed"
   echo "   URL=$COMPOSE_URL"
   echo "Falling back to using pip method"
   sudo pip3 install -U docker-compose

fi

echo "Installing IOTstack dependencies"
sudo pip3 install -U ruamel.yaml==0.16.12 blessed

# set cmdline options if possible
TARGET="/boot/cmdline.txt"
if [ -e "$TARGET" ] ; then
   unset APPEND
   for OPTION in $CMDLINE_OPTIONS ; do
      if [ $(grep -c "$OPTION" "$TARGET") -eq 0 ] ; then
         APPEND="$APPEND $OPTION"
      fi
   done
   if [ -n "$APPEND" ] ; then
      echo "Appending$APPEND to $TARGET"
      sudo sed -i.bak "s/$/$APPEND/" "$TARGET"
   fi
fi

# run the script epilog if it exists
run_pibuilder_epilog

# reboot (applies usermods and any cmdline.txt changes)
echo "$SCRIPT complete - rebooting..."
sudo touch /boot/ssh
sudo reboot
