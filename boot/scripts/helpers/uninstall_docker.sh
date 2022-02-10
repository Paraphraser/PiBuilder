#!/usr/bin/env bash

#
# Uninstalls docker:
#
# This script can be invoked as:
#
#   /uninstall_docker.sh
#

# should not run as root
[ "$EUID" -eq 0 ] && echo "This script should NOT be run using sudo" && exit 1

# support user renaming of script
SCRIPT=$(basename "$0")

# no arguments
if [ "$#" -ne 0 ]; then

    echo "Usage: $SCRIPT"
    exit 1

fi

# only really supported for Linux (intended for Raspbian but not enforced)
if [ "$(uname -s)" !=  "Linux" -o -z "$(which apt)" ] ; then

   echo "This script should only be run on Linux systems supporting 'apt'."
   exit 1

fi

# check for supervised home assistant
if apt list homeassistant-supervised 2>/dev/null | grep -q "installed" ; then

   echo "homeassistant-supervised appears to be installed. Removing docker will"
   echo "take homeassistant-supervised with it but the auto-removal also leaves"
   echo "a mess. If you really want to proceed with removing docker, you should"
   echo "run these commands first:"
   echo "   \$ ./uninstall_homeassistant-supervised.sh"
   echo "   \$ sudo reboot"
   echo "and then re-run this script to remove docker."
   exit 1

fi

# no containers should be running
if [ -n "$(docker ps -a -q)" ] ; then

   echo "Docker reports the following containers are running:"
   docker ps --format "table {{.Names}}" | sed -e "s/^/  /"
   echo "Please terminate all running containers and then retry this script"
   exit 1 

fi

# define the services
SERVICES="docker.service"

echo "Stopping and disabling $SERVICES"
echo "(ignore any errors)"
sudo systemctl stop $SERVICES
sudo systemctl disable $SERVICES

# clear the docker decks
sudo apt -y purge docker-ce docker-ce-cli containerd.io

echo "docker has been removed. A reboot is recommended but may be deferred. If"
echo "you also intend to remove docker-compose, you can defer the reboot until"
echo "after docker-compose is removed."
