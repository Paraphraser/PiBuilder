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

# pre-load list of supporting packages for Home Assistant
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

# has the user asked for home assistant?
if [ "$HOME_ASSISTANT_SUPERVISED_INSTALL" = "true" ] ; then

   # yes! use a default release if not otherwise provided in options.sh
   # https://github.com/home-assistant/os-agent/releases/latest
   HOME_ASSISTANT_AGENT_RELEASE="${HOME_ASSISTANT_AGENT_RELEASE:-"1.2.2"}"

   # check how the hardware describes itself
   case "$(grep "^Model[ :]*" /proc/cpuinfo | cut -c 10-23)" in

     "Raspberry Pi 3" )
       HINT="raspberrypi3"
       ;;

     "Raspberry Pi 4" )
       HINT="raspberrypi4"
       ;;

     *)
       echo "Home Assistant Supervised Install is enabled but this hardware does not"
       echo "identify as either Raspberry Pi 3 or 4. Either this configuration is not"
       echo "supported by Home Assistant or has not been tested for PiBuilder. If you"
       echo "wish to try anyway, modify this script to include your hardware in this"
       echo "case statement."
       exit 1
       ;;

   esac

   # the agent is ALWAYS armv7 - aarch64 does not work
   #    dpkg: error processing archive /tmp/Imx1h-DOWNLOADS/os-agent_1.2.2_linux_aarch64.deb (--install):
   #          package architecture (arm64) does not match system (armhf)

   AGENT="os-agent_${HOME_ASSISTANT_AGENT_RELEASE}_linux_armv7.deb"

   echo -e "\n\n\n========================================================================\n"
   echo "Hint: during Home Assistant installation, please choose:"
   echo "           \"$HINT\""
   echo "      at the \"Select machine type\" prompt"
   echo -e "\n========================================================================\n"

   sleep 5

   # construct a temporary directory to download into
   DOWNLOADS=$(mktemp -d /tmp/XXXXX-DOWNLOADS)

   # construct the URLs to download from
   AGENT_URL="https://github.com/home-assistant/os-agent/releases/download/$HOME_ASSISTANT_AGENT_RELEASE/$AGENT"
   PACKAGE_URL="https://github.com/home-assistant/supervised-installer/releases/latest/download/homeassistant-supervised.deb"

   # define what we will be downloading
   AGENT_DEB="$DOWNLOADS/$AGENT"
   PACKAGE_DEB="$DOWNLOADS/homeassistant-supervised.deb"

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
            sudo dpkg -i "$DEB"
            if [ $? -ne 0 ] ; then
               echo "Unable to install Home Assistant package $DEB. Try running:"
               echo "   gdbus introspect --system --dest io.hass.os --object-path /io/hass/os"
               break
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

      fi

   else

      # no! did not succeed in downloading agent
      echo "Unable to download Home Assistant agent from $AGENT_URL"
      echo "   HOME_ASSISTANT_AGENT_RELEASE=$HOME_ASSISTANT_AGENT_RELEASE"
      echo "Is that still correct? Check:"
      echo "   https://github.com/home-assistant/os-agent/releases/latest"
      echo "then set HOME_ASSISTANT_AGENT_RELEASE in $USEROPTIONS"
      echo "and retry $SCRIPT."

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
DOCKER_COMPOSE_VERSION="${DOCKER_COMPOSE_VERSION:-"v2.1.1"}"
DOCKER_COMPOSE_ARCHITECTURE="${DOCKER_COMPOSE_ARCHITECTURE:-"armv7"}"

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

# run the script epilog if it exists
run_pibuilder_epilog

# reboot (applies usermods and any network manager change)
echo "$SCRIPT complete - rebooting..."
sudo reboot
