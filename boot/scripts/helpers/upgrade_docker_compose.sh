#!/usr/bin/env bash

#
# Downloads modern docker-compose from:
#
#   https://github.com/docker/compose/releases
#
# This script can be invoked as:
#
# 1. ./upgrade_docker_compose.sh
# 2. ./upgrade_docker_compose.sh v2.2.3
# 3. DOCKER_COMPOSE_VERSION=v2.2.3 ./upgrade_docker_compose.sh
#
# The parameter takes precedence over the environment variable if both
# are used.
#
# -----
#
# Platform defaults to the lower-case version of "uname -s". It can be
# overridden with:
#
#  DOCKER_COMPOSE_PLATFORM=platform
#
# Example:
#
#  DOCKER_COMPOSE_PLATFORM=linux ./upgrade_docker_compose.sh v2.2.3
#
# -----
#
# Architecture defaults to a best guess based on "uname -m". If the
# guess turns out to be wrong, it can be overridden with:
#
#  DOCKER_COMPOSE_ARCHITECTURE=architecture
#
# Example:
#
#  DOCKER_COMPOSE_ARCHITECTURE=armv7 ./upgrade_docker_compose.sh v2.2.3
#
# -----
#
# Despite the name, this script will also downgrade. If, for example,
# you are running docker-compose v2.2.3 and want to revert to v2.2.2
# the script will do that.
#

# should run as root
[ "$EUID" -ne 0 ] && echo "This script should be run using sudo" && exit -1

# the default version of docker-compose at the moment is
DOCKER_COMPOSE_VERSION_DEFAULT="v2.2.3"

# at most one argument
if [ "$#" -gt 1 ]; then

    echo "Usage: sudo $SCRIPT" {version}
    echo "   eg: sudo $SCRIPT $DOCKER_COMPOSE_VERSION_DEFAULT"
    echo " note: the 'v' is REQUIRED"
    exit -1

fi

# support three forms of invocation for the version
DOCKER_COMPOSE_VERSION="${DOCKER_COMPOSE_VERSION:-"$DOCKER_COMPOSE_VERSION_DEFAULT"}"
DOCKER_COMPOSE_VERSION=${1:-$DOCKER_COMPOSE_VERSION}

# select default platform and use that unless overridden
declare -l DEFAULT_PLATFORM=$(uname -s)
DOCKER_COMPOSE_PLATFORM="${DOCKER_COMPOSE_PLATFORM:-"$DEFAULT_PLATFORM"}"

# select default architecture
case "$(uname -m)" in

  "aarch64" )
    if [ $(lscpu | grep -c "32-bit, 64-bit") -eq 1 ] ; then
       # running full 64-bit OS
       DEFAULT_ARCHITECTURE="aarch64"
    else
       # running 32-bit user mode with 64-bit kernel
       DEFAULT_ARCHITECTURE="armv7"
    fi
    ;;

  "armv7l" )
    DEFAULT_ARCHITECTURE="armv7"
    ;;

  "armv6l" )
    DEFAULT_ARCHITECTURE="armv6"
    ;;

  *)
    # accept whatever uname supplies
    DEFAULT_ARCHITECTURE="$(uname -m)"
    ;;

esac

# use default architecture unless overridden
DOCKER_COMPOSE_ARCHITECTURE="${DOCKER_COMPOSE_ARCHITECTURE:-"$DEFAULT_ARCHITECTURE"}"

# construct the URL
COMPOSE_HOME="https://github.com/docker/compose/releases"
COMPOSE_URL="$COMPOSE_HOME/download/$DOCKER_COMPOSE_VERSION/docker-compose-$DOCKER_COMPOSE_PLATFORM-$DOCKER_COMPOSE_ARCHITECTURE"

# the target directories for installation are
CALLER_HOME=$(eval echo "~$SUDO_USER")
PLUGINS_DIR="$CALLER_HOME/.docker/cli-plugins"
BIN_PATH_DIR="/usr/local/bin"

# ensure the plugins directory exists and belongs to the caller
mkdir -p "$PLUGINS_DIR"

# ordered list of candidate directories
read -r -d '' INSTALL_DIRS <<-EOF
	$BIN_PATH_DIR
	/usr/libexec/docker/cli-plugins
	/usr/local/libexec/docker/cli-plugins
	/usr/lib/docker/cli-plugins
	/usr/local/lib/docker/cli-plugins
	/root/.docker/cli-plugins
	$PLUGINS_DIR
EOF

# search for docker-compose
WHERE=$(which docker-compose)

# is docker-compose installed anywhere?
if [ -n "$WHERE" ] ; then

   # yes! is it the obsolete version?
   if [ "$WHERE" = "/usr/bin/docker-compose" ] ; then

      # yes! we can't do anything with that
      echo "The version of docker-compose installed on your system is obsolete. It"
      echo "was probably installed by an IOTstack script using:"
      echo "   \$ sudo apt install docker-compose"
      echo "It is not safe for this script to uninstall docker-compose because it"
      echo "sometimes takes docker with it and then you have a serious mess to clean"
      echo "up. What you should do is:"
      echo "1. If IOTstack is running, take it down."
      echo "2. If any other docker containers are running (eg hass.io or containers"
      echo "   you have started yourself with docker run), stop and remove them."
      echo "3. Run the command:"
      echo "      \$ sudo apt remove docker-compose"
      echo "4. If that removes docker then re-install it using its convenience"
      echo "   script:"
      echo "      \$ curl -fsSL https://get.docker.com | sudo sh"
      echo "5. Re-run this script to install modern docker-compose."
      echo "6. Start your containers."
      echo ""
      echo "If step 3 doesn't remove docker but re-running this script is unable"
      echo "to install modern docker-compose, you may need to use brute force."
      echo "Repeat steps 1 and 2, and then run these commands:"
      echo "   \$ sudo apt -y purge docker-ce docker-ce-cli containerd.io"
      echo "   \$ sudo apt -y remove docker-compose"
      echo "   \$ sudo pip3 uninstall -y docker-compose"
      echo "   \$ curl -fsSL https://get.docker.com | sudo sh"
      echo "   \$ sudo usermod -G docker -a $USER"
      echo "   \$ sudo reboot"
      echo "and then pick up from step 5."

      exit 1

   fi

   # so, there is a docker-compose but it isn't the obsolete version
   # is it the python version?
   if [ $(file "$WHERE" | grep -c "Python script") -gt 0 ] ; then

      # yes!
      echo "Python-based version of docker-compose found. Assuming it was installed"
      echo "using pip3. Trying to remove it using the same method"
      pip3 uninstall -y docker-compose

      # re-try the search for docker-compose
      WHERE=$(which docker-compose)

      # found anything?
      if [ -n "$WHERE" ] ; then
         echo "Attempts to remove the Python-based version of docker-compose seem to"
         echo "have failed because docker-compose is still installed. You will need to"
         echo "investigate why. The problematic file is $WHERE"
         exit 1
      fi

   else

      # it isn't obsolete and it isn't the python script. Assume it's
      # some version of the modern script. Fetch that detail
      INSTALLED_VERSION_STRING=$(docker-compose version)

      # construct a string for the target version
      TARGET_VERSION_STRING="Docker Compose version ${DOCKER_COMPOSE_VERSION}"

      # are those the same?
      if [ "$INSTALLED_VERSION_STRING" = "$TARGET_VERSION_STRING" ] ; then

         echo "The installed version is $INSTALLED_VERSION_STRING and that seems to be"
         echo "the same as the version you are requesting: $DOCKER_COMPOSE_VERSION."
         exit 0

      fi

      # not the same version - iterate to remove all traces
      for DIR in $INSTALL_DIRS ; do
        CANDIDATE="$DIR/docker-compose"
        if [ -e "$CANDIDATE" ] ; then
           echo "Removing $CANDIDATE"
           rm -f "$CANDIDATE"
        fi
      done

   fi

fi

# repeat the search for docker-compose
WHERE=$(which docker-compose)

# this time the answer should be "not installed"
if [ -z "$WHERE" ] ; then

   # the target is is in the plugins directory
   TARGET="$PLUGINS_DIR/docker-compose"

   # report
   echo "Attempting to fetch docker-compose version $DOCKER_COMPOSE_VERSION for $DOCKER_COMPOSE_PLATFORM $DOCKER_COMPOSE_ARCHITECTURE"
   echo "architecture from:"
   echo "   $COMPOSE_URL"

   # try to fetch
   curl -L "$COMPOSE_URL" -o "$TARGET"

   # did the download succeed?
   if [ $? -eq 0 ] ; then

      # yes! set execute permission on the target
      chmod +x "$TARGET"

      # assign ownership of the whole structure to the correct user
      chown -R "$SUDO_UID:$SUDO_GID" "$PLUGINS_DIR"

      # and also copy to /usr/local/bin/
      cp "$TARGET" "$BIN_PATH_DIR"

      # yes! report success
      echo "Modern docker-compose installed as $TARGET"
      echo "   Identifies as $(docker-compose version)"
      echo "Also copied to $BIN_PATH_DIR. You can call it as either:"
      echo "   docker-compose version"
      echo "or as a plugin - without the hyphen - via:"
      echo "   docker compose version"
      echo "You can check for later versions at $COMPOSE_HOME"
      echo "Docker documentation recommends adding the following to your .profile"
      echo "   export COMPOSE_DOCKER_CLI_BUILD=1"
      echo "   export DOCKER_BUILDKIT=1"
      echo "References:"
      echo "   https://www.docker.com/blog/faster-builds-in-compose-thanks-to-buildkit-support/"
      echo "   https://docs.docker.com/compose/reference/build/#native-build-using-the-docker-cli"
      echo "   https://docs.docker.com/compose/reference/envvars/#compose_docker_cli_build"
      echo "   https://docs.docker.com/develop/develop-images/build_enhancements/#to-enable-buildkit-builds"

   else

      # no! failed. That means TARGET is useless
      rm -f "$TARGET"

      echo "Attempt to download docker-compose failed. Falling back to pip method."
      pip3 install -U docker-compose

   fi

else

   echo "Attempts to remove older versions of docker-compose seem to have failed"
   echo "because docker-compose is still installed. You will need to investigate"
   echo "why. The problematic file is $WHERE"
   exit 1

fi
