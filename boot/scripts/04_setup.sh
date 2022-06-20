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

COMPOSE_PLUGIN="/usr/libexec/docker/cli-plugins/docker-compose"
COMPOSE_SYMLINK="/usr/local/bin/docker-compose"

read -r -d '' COMPOSEFAIL <<-EOM
========================================================================
$SCRIPT expects the docker convenience script to install docker-compose
as a plug-in at:
   $COMPOSE_PLUGIN
Unfortunately, that file can't be found. This is probably because the
convenience script has changed and is something that PiBuilder can't
control. Please open an issue at:
   https://github.com/Paraphraser/PiBuilder/issues
========================================================================
EOM

# install Docker
echo "Installing docker"
curl -fsSL https://get.docker.com | sudo sh
if [ $? -ne 0 ] ; then
   echo "$DOCKERFAIL"
   exit 1
fi

# installing docker now brings docker-compose-plugin with it. After
# being installed by the convenience script, both are maintained by
# the normal apt update/upgrade duet.The convenience script installs
# /usr/libexec/docker/cli-plugins/docker-compose which is not in the
# PATH. Rather than trying to manipulate the PATH, the simplest
# approach to keeping the "docker-compose" command functional (as
# distinct from "docker compose" as a plugin) is a symbolic link.

# did the convenience script install the plugin?
if [ -f "$COMPOSE_PLUGIN" ] ; then
   # yes! go with the symlink
   echo "Creating symbolic link for docker-compose-plugin"
   echo "  - $COMPOSE_SYMLINK linked to"
   echo "  - $COMPOSE_PLUGIN"
   sudo ln -s "$COMPOSE_PLUGIN" "$COMPOSE_SYMLINK"
else
   echo "$COMPOSEFAIL"
   exit 1
fi

echo "Setting groups required for docker and bluetooth"
sudo usermod -G docker -a $USER
sudo usermod -G bluetooth -a $USER

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
