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

# defaults which can be overridden by adding the variable to the
# options script, or inline on the call to this script, or exported
# to the environment prior to calling this script
#
# default location of IOTstack
IOTSTACK=${IOTSTACK:-"$HOME/IOTstack"}
IOTSTACK=$(realpath "$IOTSTACK")

# add these to /boot/cmdline.txt
CMDLINE_OPTIONS="cgroup_memory=1 cgroup_enable=memory"

# canned general advisory if IOTstack doesn't exist
read -r -d "\n" IOTSTACKFAIL <<-EOM
========================================================================
The $IOTSTACK directory does not exist. This is normally
created by the 03 script when it clones IOTstack from GitHub. The most
common explanation for the directory being missing is because the 03
script did not complete normally, and the most common reason for that
is due to one or more failures of "sudo apt install <package>". You
need to keep re-running the 03 script until it completes normally.

Another reason why the $IOTSTACK directory might not
exist is because you are running this script simply to install docker
and docker-compose but without running the preceding PiBuilder scripts.
That's OK but you do need to clone IOTstack from GitHub first.
========================================================================
EOM

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

# canned general advisory if docker-compose can't be symlinked
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

# make sure the IOTstack directory exists. This is done before running
# the docker convenience script so that it is safe to either re-run
# the 03 script until it completes, or bypass the check by cloning
# the IOTstack repo
if [ ! -d "$IOTSTACK" ] ; then
   echo "$IOTSTACKFAIL"
   exit 1
fi

# install Docker
# see https://docs.docker.com/engine/install/debian/#install-using-the-convenience-script
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
sudo /usr/sbin/usermod -G docker -a $USER
sudo /usr/sbin/usermod -G bluetooth -a $USER

# the menu now has some specific structural requirements for its dependencies
echo "Removing any Python dependencies which may conflict with the IOTstack menu"
for P in virtualenv ruamel.yaml blessed ; do
   sudo PIP_BREAK_SYSTEM_PACKAGES=1 pip3 uninstall -y "$P"
   PIP_BREAK_SYSTEM_PACKAGES=1 pip3 uninstall -y "$P"
done

# the menu now has its own requirements list - process that
TARGET="$IOTSTACK/requirements-menu.txt"
if [ -e "$TARGET" ] ; then
   echo "Satisfying IOTstack menu requirements" 
   PIP_BREAK_SYSTEM_PACKAGES=1 pip3 install -r "$TARGET"
fi

# and, just on the off-chance that this script is being run to reinstall
# docker and docker-compose, in which case the virtual environment might
# already exist, clobber that so it will be recreated when the menu runs
sudo rm -rf "$IOTSTACK/.virtualenv-menu"

# set cmdline options if possible
TARGET=$(path_to_pi_boot_file "cmdline.txt")
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
sudo /usr/sbin/reboot
