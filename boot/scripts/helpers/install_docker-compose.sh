#!/usr/bin/env bash

#
# Downloads modern docker-compose from:
#
#   https://github.com/docker/compose/releases
#
# This script can be invoked as:
#
# 1. sudo ./install_docker-compose.sh
# 2. sudo ./install_docker-compose.sh vX.X.X
# 3. sudo DOCKER_COMPOSE_VERSION=vX.X.X ./install_docker-compose.sh
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
#  DOCKER_COMPOSE_PLATFORM=linux ./install_docker-compose.sh vX.X.X
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
#  DOCKER_COMPOSE_ARCHITECTURE=armv7 ./install_docker-compose.sh vX.X.X
#
# -----
#
# Despite the name, this script will also downgrade. If, for example,
# you are running docker-compose vX.X.2 and want to revert to vX.X.1
# the script will do that.
#

# SHOULD run as root - the exception to the usual rule
[ "$EUID" -ne 0 ] && echo "This script SHOULD be run using sudo" && exit 1

# support user renaming of script
SCRIPT=$(basename "$0")

running_OS_release() {
   if [ -e "/etc/os-release" ] ; then
      . "/etc/os-release"
      if [ -n "$VERSION_CODENAME" ] ; then
         echo "$VERSION_CODENAME"
         return 0
      fi
   fi
   echo "unknown"
   return 1
}

is_running_OS_release() {
   if [ "$(running_OS_release)" = "$1" ] ; then
      return 0
   fi 
   return 1
}

if is_running_OS_release bookworm ; then
   echo "Note: pip3 installs will bypass externally-managed environment check"
   PIBUILDER_PYTHON_OPTIONS="--break-system-packages"
fi

# the default version of docker-compose at the moment is
DOCKER_COMPOSE_VERSION_DEFAULT="v2.27.0"

read -r -d '' COMPOSENOTES <<-EOM
\n
===============================================================================
This script can't run until all existing copies of docker-compose have been
removed. Before you proceed, I strongly recommend that you read:

   https://github.com/Paraphraser/PiBuilder/blob/master/reinstallation.md

If - and ONLY if - your existing version is v2.0.0 or later, you can upgrade to
any v2.x.x version of docker-compose by:

1. Running the "uninstall_docker-compose.sh" script, and then
2. Re-running this script, passing the target version. For example:

      sudo $SCRIPT $DOCKER_COMPOSE_VERSION_DEFAULT
===============================================================================
\n
EOM

# is docker-compose already installed?
if [ -n "$(which docker-compose)" ] ; then

   # yes! complain
   echo -e "$COMPOSENOTES"
   
   # and exit
   exit 2

fi

# at most one argument
if [ "$#" -gt 1 ]; then

    echo "Usage: sudo $SCRIPT {version}"
    echo "   eg: sudo $SCRIPT $DOCKER_COMPOSE_VERSION_DEFAULT"
    echo " note: the 'v' is REQUIRED"
    exit 1

fi

# support three forms of invocation for the version
DOCKER_COMPOSE_VERSION="${DOCKER_COMPOSE_VERSION:-"$DOCKER_COMPOSE_VERSION_DEFAULT"}"
DOCKER_COMPOSE_VERSION=${1:-$DOCKER_COMPOSE_VERSION}

# at the moment, versions begin with "v"
if ! [[ "$DOCKER_COMPOSE_VERSION" =~ ^v ]] ; then

   echo "version numbers for docker-compose begin with 'v' - did you mean v$DOCKER_COMPOSE_VERSION ?"
   exit 1
   
fi

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
      echo "was probably installed by an IOTstack script using 'apt'. It is not safe"
      echo "for this script to just uninstall docker-compose because it sometimes"
      echo "takes docker with it and that, in turn, can take down other things that"
      echo "depend on docker. Then you have a serious mess to clean up. Assuming"
      echo "this is a Linux system, the best thing you can do now is to use some"
      echo "brute force:"
      echo ""
      echo "1. If IOTstack is running, take it down."
      echo "2. If any other docker containers are running (eg containers you have"
      echo "   started yourself with 'docker run'), stop and remove them."
      echo "3. Remove anything else that needs docker."
      echo "4. Uninstall docker by running¹:"
      echo "      \$ ./uninstall_docker.sh"
      echo "5. Remove all copies of docker-compose by running¹:"
      echo "      \$ ./uninstall_docker-compose.sh"
      echo "6. Reboot."
      echo ""
      echo "That gives you a clean slate. The best way to reinstall docker and"
      echo "docker-compose is to run the '04_setup.sh' script²:"
      echo ""
      echo "   \$ /boot/scripts/04_setup.sh"
      echo ""
      echo "¹ script is in the PiBuilder 'scripts/helpers' folder"
      echo "² script is in the PiBuilder 'scripts' folder"

      exit 1

   fi

   # so, there is a docker-compose but it isn't the obsolete version
   # is it the python version?
   if [ $(file "$WHERE" | grep -c "Python script") -gt 0 ] ; then

      # yes!
      echo "Python-based version of docker-compose found. Assuming it was installed"
      echo "using pip3. Trying to remove it using the same method"
      pip3 uninstall -y $PIBUILDER_PYTHON_OPTIONS docker-compose

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
   wget -q "$COMPOSE_URL" -O "$TARGET"

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
      echo "   export DOCKER_BUILDKIT=1"
      echo "Reference:"
      echo "   https://docs.docker.com/develop/develop-images/build_enhancements/#to-enable-buildkit-builds"

   else

      # no! failed. That means TARGET is useless
      rm -f "$TARGET"

      echo "Attempt to download docker-compose failed. Falling back to pip method."
      pip3 install -U $PIBUILDER_PYTHON_OPTIONS docker-compose

   fi

else

   echo "Attempts to remove older versions of docker-compose seem to have failed"
   echo "because docker-compose is still installed. You will need to investigate"
   echo "why. The problematic file is $WHERE"
   exit 1

fi
