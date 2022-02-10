#!/usr/bin/env bash

#
# Uninstalls docker:
#
# This script can be invoked as:
#
#   uninstall_homeassistant-supervised.sh
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

# define the services
SERVICES="hassio-supervisor.service hassio-apparmor.service"

# define the expected containers
read -r -d '' HASSIO <<-'EOF'
	hassio_multicast
	hassio_cli
	hassio_audio
	hassio_dns
	homeassistant
	hassio_observer
	hassio_supervisor 
EOF

# check that homeassistant-supervised is actually installed
if apt list homeassistant-supervised 2>/dev/null | grep -q "installed" ; then

    echo "Stopping and disabling $SERVICES"
    echo "(ignore any errors)"
    sudo systemctl stop $SERVICES
    sudo systemctl disable $SERVICES
    
    echo "Stopping and removing any running homeassistant-supervised containers"
    echo "(ignore any errors)"
    docker stop $HASSIO
    docker rm $HASSIO
    
    echo "Removing the internal 'hassio' docker network"
    docker network rm hassio

    echo "Purging homeassistant-supervised installation. You should ignore any"
    echo "warnings about apparmor and docker."
    sudo apt -y purge homeassistant-supervised

    if [ $? -eq 0 ] ; then
        echo "homeassistant-supervised has been removed. A reboot is STRONGLY recommended."
    fi

else

   echo "'apt' reports that 'homeassistant-supervised' is not installed"
   exit 1

fi
