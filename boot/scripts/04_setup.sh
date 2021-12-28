#!/usr/bin/env bash

# takes an optional argument. If the value of that argument is "true" (the literal
# string minus the quotes) then Supervised Home Assistant will be installed. Any other
# value results in Supervised Home Assistant not being installed. If the argument is
# omitted then Supervised Home Assistant will only be installed if the value of the
# HOME_ASSISTANT_SUPERVISED_INSTALL variable in the options file is "true".

# should not run as root
[ "$EUID" -eq 0 ] && echo "This script should NOT be run using sudo" && exit -1

# the name of this script is
SCRIPT=$(basename "$0")

if [ "$#" -gt 1 ]; then
    echo "Usage: $SCRIPT" {false|true}
    echo "  if optional argument is:"
    echo "      true = forces Supervised Home Assistant installation"
    echo "     false = forbids Supervised Home Assistant installation"
    exit -1
fi

# declare path to support directory and import common functions
SUPPORT="/boot/scripts/support"
. "$SUPPORT/pibuilder/functions.sh"

# import user options and run the script prolog - if they exist
run_pibuilder_prolog

# pre-load list of supporting packages for Home Assistant.
#
# Note https://github.com/home-assistant/supervised-installer lists
# dependencies as:
#   jq wget curl udisks2 libglib2.0-bin network-manager dbus
# which means:
#   apparmor apparmor-profiles apparmor-utils apt-transport-https
#   avahi-daemon ca-certificates software-properties-common
# are probably no longer necessary. This needs testing.
#
PACKAGES="$(mktemp -p /dev/shm/)"
cat <<-HASSIO_PACKAGES >"$PACKAGES"
apparmor
apparmor-profiles
apparmor-utils
apt-transport-https
avahi-daemon
ca-certificates
curl
dbus
jq
libglib2.0-bin
software-properties-common
udisks2
wget
network-manager
HASSIO_PACKAGES

# we expect HOME_ASSISTANT_SUPERVISED_INSTALL to be set in the options file
# which is imported above. If HOME_ASSISTANT_SUPERVISED_INSTALL is not defined
# in the options file then we set it here with a default of false (do not install)
HOME_ASSISTANT_SUPERVISED_INSTALL=${HOME_ASSISTANT_SUPERVISED_INSTALL:-false}

# we support an argument to this script. If it is present then its value
# overrides HOME_ASSISTANT_SUPERVISED_INSTALL. If that value is "true" then
# Supervised Home Assistant will be installed.
HOME_ASSISTANT_SUPERVISED_INSTALL=${1:-$HOME_ASSISTANT_SUPERVISED_INSTALL}

# has the user asked for home assistant?
if [ "$HOME_ASSISTANT_SUPERVISED_INSTALL" = "true" ] ; then

   # yes! references:
   #   https://github.com/home-assistant/supervised-installer
   #   https://github.com/home-assistant/supervised-installer/releases
   #   https://github.com/home-assistant/os-agent/releases/latest

   # yes! use a default release if not otherwise provided in options.sh
   HOME_ASSISTANT_AGENT_RELEASE="${HOME_ASSISTANT_AGENT_RELEASE:-"1.2.2"}"

   # check how the hardware describes itself
   HARDWARE_IDENTITY=$(grep "^Model[ :]*" /proc/cpuinfo | cut -c 10-23)
   case "$HARDWARE_IDENTITY" in

     "Raspberry Pi 3" )
       if is_running_OS_64bit ; then
          PLATFORM_CHOICE="raspberrypi3-64"
          HOME_ASSISTANT_ARCHITECTURE="aarch64"
       else
          PLATFORM_CHOICE="raspberrypi3"
          HOME_ASSISTANT_ARCHITECTURE="armv7"
       fi
       ;;

     "Raspberry Pi 4" )
       if is_running_OS_64bit ; then
          PLATFORM_CHOICE="raspberrypi4-64"
          HOME_ASSISTANT_ARCHITECTURE="aarch64"
       else
          PLATFORM_CHOICE="raspberrypi4"
          HOME_ASSISTANT_ARCHITECTURE="armv7"
       fi
       ;;

     "Raspberry Pi Z" )
       PLATFORM_CHOICE="raspberrypi"
       HOME_ASSISTANT_ARCHITECTURE="armv7"
       ;;

     *)
       echo "Home Assistant Supervised Install is enabled but this hardware identifies"
       echo "as \"$HARDWARE_IDENTITY\". Either this configuration is not supported by"
       echo "Home Assistant or has not been tested for PiBuilder. If you wish to try"
       echo "anyway, modify this script to include your hardware in this case statement."
       exit 1
       ;;

   esac

   AGENT="os-agent_${HOME_ASSISTANT_AGENT_RELEASE}_linux_${HOME_ASSISTANT_ARCHITECTURE}.deb"

   # construct a temporary directory to download into
   DOWNLOADS=$(mktemp -d /tmp/XXXXX-DOWNLOADS)

   # construct the URLs to download from
   AGENT_URL="https://github.com/home-assistant/os-agent/releases/download/$HOME_ASSISTANT_AGENT_RELEASE/$AGENT"
   PACKAGE_URL="https://github.com/home-assistant/supervised-installer/releases/latest/download/homeassistant-supervised.deb"
   
   echo "Supervised Home Assistant installation will be based on:"
   echo "    Agent URL: $AGENT_URL"
   echo "  Package URL: $PACKAGE_URL"

   # define what we will be downloading
   AGENT_DEB="$DOWNLOADS/$AGENT"
   PACKAGE_DEB="$DOWNLOADS/homeassistant-supervised.deb"
   
   # create a pre-seed file. To revert to a menu:
   # 1. comment-out the next three lines
   # 2. remove the DEBIAN_FRONTEND=noninteractive further down
   # valid platform choices are:
   #    generic-x86-64, odroid-c2, odroid-n2, odroid-xu, qemuarm,
   #    qemuarm-64, qemux86, qemux86-64, raspberrypi, raspberrypi2,
   #    raspberrypi3, raspberrypi4, raspberrypi3-64, raspberrypi4-64,
   #    tinker, khadas-vim3

   PRESEED="$DOWNLOADS/preseed.cfg"
   echo -e "homeassistant-supervised\tha/machine-type\tselect\t${PLATFORM_CHOICE}" >"$PRESEED"
   sudo debconf-set-selections "$PRESEED"

   # try to download the agent
   wget -O "$AGENT_DEB" "$AGENT_URL"

   # did the agent download succeed?
   if [ $? -eq 0 -a -e "$AGENT_DEB" ] ; then

      # yes! attempt to download the package
      wget -O "$PACKAGE_DEB" "$PACKAGE_URL"

      # did the package download succeed?
      if [ $? -eq 0 -a -e "$PACKAGE_DEB" ] ; then

         # yes! install dependencies
         echo "Installing Home Assistant dependencies"
         install_packages "$PACKAGES"

         # install Docker
         echo "Installing docker"
         curl -fsSL https://get.docker.com | sudo sh

         # iterate home assistant components
         echo "Installing Home Assistant"
         for DEB in "$AGENT_DEB" "$PACKAGE_DEB" ; do
            DEBIAN_FRONTEND=noninteractive sudo dpkg -i "$DEB"
            if [ $? -ne 0 ] ; then
               echo "Unable to install Home Assistant package $DEB. Try running:"
               echo "   gdbus introspect --system --dest io.hass.os --object-path /io/hass/os"
               exit 1
            fi
         done

        # patch network manager to prevent random WiFi MAC. IOTstack
        # implies a SERVER which MAY be WiFi-only. Servers need
        # predictable IP addresses, either from static assignment or
        # static binding in DHCP. The latter depends on a predictable
        # MAC address. Will take effect on next reboot.
        try_patch "/etc/NetworkManager/NetworkManager.conf" "disable random Wifi MAC"

      else

         # no! did not succeed in downloading package
         echo "Unable to download Home Assistant package from $PACKAGE_URL"
         exit 1

      fi

   else

      # no! did not succeed in downloading agent
      echo "Unable to download Home Assistant agent from $AGENT_URL"
      echo "   HOME_ASSISTANT_AGENT_RELEASE=$HOME_ASSISTANT_AGENT_RELEASE"
      echo "Is that still correct? Check:"
      echo "   https://github.com/home-assistant/os-agent/releases/latest"
      echo "then set HOME_ASSISTANT_AGENT_RELEASE in $USEROPTIONS"
      echo "and retry $SCRIPT."
      exit 1

   fi

   # clean up
   rm -rf "$DOWNLOADS"

else

   # otherwise just install Docker
   echo "Installing docker"
   curl -fsSL https://get.docker.com | sudo sh

fi

echo "Setting groups required for docker and bluetooth"
sudo usermod -G docker -a $USER
sudo usermod -G bluetooth -a $USER

echo "Installing docker-compose"

# apply defaults for docker-compose (can be overridden in options.sh)
# https://github.com/docker/compose/releases
DOCKER_COMPOSE_VERSION="${DOCKER_COMPOSE_VERSION:-"v2.2.2"}"
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
$SUDO curl -L "$COMPOSE_URL" -o "$TARGET"

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

# try to add support for docker stats - applies from next reboot
TARGET="/boot/cmdline.txt"
APPEND="cgroup_memory=1 cgroup_enable=memory"
if [ -e "$TARGET" ] ; then
   if [ $(grep -c "$APPEND" "$TARGET") -eq 0 ] ; then
      echo "Adding support for \"docker stats\""
      sudo sed -i.bak "s/$/ $APPEND/" "$TARGET"
   fi
fi

# run the script epilog if it exists
run_pibuilder_epilog

# reboot (applies usermods and any network manager change)
echo "$SCRIPT complete - rebooting..."
sudo touch /boot/ssh
sudo reboot
