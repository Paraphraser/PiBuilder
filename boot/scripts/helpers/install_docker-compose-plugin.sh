#!/usr/bin/env bash

#
# Uses apt to install docker-compose-plugin and sets up a symlink
# such that
#   /usr/local/bin/docker-compose
# points to
#   /usr/libexec/docker/cli-plugins/docker-compose
#
# Thereafter, whenever docker-compose-plugin is updated by apt, the
# symlink will still be in place and either "docker-compose" or
# "docker compose" will launch the same version of the binary.
#

# should not run as root
[ "$EUID" -eq 0 ] && echo "This script should NOT be run using sudo" && exit -1

# the name of this script is
SCRIPT=$(basename "$0")

# is docker-compose already installed?
if [ -n "$(which docker-compose)" ] ; then

   # yes! complain
   echo "$SCRIPT can't run until all existing copies of docker-compose have been
removed"
   echo "Hint: run uninstall_docker-compose.sh then re-run $SCRIPT".

   # and exit
   exit 2

fi

# no arguments supported
if [ "$#" -gt 0 ]; then
    echo "Usage: $SCRIPT"
    exit -1
fi

# expected location of plugin when apt does the job
COMPOSE_PLUGIN="/usr/libexec/docker/cli-plugins/docker-compose"

# symlink to be set up to the above
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

# install the plugin
sudo apt install -y docker-compose-plugin

# did the install succeed?
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

