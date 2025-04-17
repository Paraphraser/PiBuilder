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

# constants - the releases page and JSON API
COMPOSE_HOME="https://github.com/docker/compose/releases"
COMPOSE_JSON="https://api.github.com/repos/docker/compose/releases/latest"

# the default version of docker-compose is the latest available
DOCKER_COMPOSE_VERSION_DEFAULT="latest"

# is docker-compose already installed?
if [ -n "$(which docker-compose)" ] ; then

	# yes! complain
	cat <<-REMOVEALL

	===============================================================================
	This script can't run until all existing copies of docker-compose have been
	removed. Before you proceed, I strongly recommend that you read:

	   https://github.com/Paraphraser/PiBuilder/blob/master/reinstallation.md

	If - and ONLY if - your existing version is v2.0.0 or later, you can upgrade to
	any v2.x.x version of docker-compose by:

	1. Running the "uninstall_docker-compose.sh" script, and then
	2. Re-running this script.
	===============================================================================

	REMOVEALL

	# and exit
	exit 2

fi

# at most one argument
if [ "$#" -gt 1 ]; then

	cat <<-USAGE

	Usage: sudo $SCRIPT {version}

	 note: Omitting the argument defaults to the 'latest' version.
	       If you pass an explicit version, it MUST start with a 'v' (eg 'v2.35.0')

	USAGE
	exit 1

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

# and the name of the file to be downloaded is
DOCKER_COMPOSE_TARGET="docker-compose-$DOCKER_COMPOSE_PLATFORM-$DOCKER_COMPOSE_ARCHITECTURE"

# have we been asked to install the latest version?
if [ "$DOCKER_COMPOSE_VERSION" = "latest" ] ; then

	# yes! figure out the URL by parsing the JSON
	COMPOSE_URL=$(wget -qO - "$COMPOSE_JSON" | jq -r ".assets[] | select(.name | endswith (\"$DOCKER_COMPOSE_TARGET\")) | .browser_download_url")

	# did that succeed?
	if [ $? -ne 0 ] ; then

		cat <<-LATESTFAIL

		Doh! Failed to obtain the relevant URL for:
		   $DOCKER_COMPOSE_TARGET
		by parsing the JSON-format descriptions at:
		   $COMPOSE_JSON

		Here is a workaround:
		1. Open your browser at $COMPOSE_HOME
		2. From that page, work out the actual version number you need.
		3. Re-run this command, passing it the version number. For example:

		   \$ sudo ./$SCRIPT v2.35.0

		LATESTFAIL

		exit 1

	fi

else

	# user-supplied versions should conform with a pattern like v2.25.0 - check it
	if ! [[ "$DOCKER_COMPOSE_VERSION" =~ ^v[0-9]{1,2}\.[0-9]{1,2}\.[0-9]{1,2}$ ]] ; then

		cat <<-VERSIONFAIL
		Version numbers for docker-compose must conform with the pattern 'vN.N.N'
		The leading 'v' and the '.' separators are required. Each N can be one or two digits.
		VERSIONFAIL

		exit 1

	fi

	# construct the URL
	COMPOSE_URL="$COMPOSE_HOME/download/$DOCKER_COMPOSE_VERSION/$DOCKER_COMPOSE_TARGET"

fi


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
		cat <<-OBSOLETE

		The version of docker-compose installed on your system is obsolete. It
		was probably installed by an IOTstack script using 'apt'. It is not safe
		for this script to just uninstall docker-compose because it sometimes
		takes docker with it and that, in turn, can take down other things that
		depend on docker. Then you have a serious mess to clean up. Assuming
		this is a Linux system, the best thing you can do now is to use some
		brute force:

		1. If IOTstack is running, take it down.
		2. If any other docker containers are running (eg containers you have
		   started yourself with 'docker run'), stop and remove them.
		3. Remove anything else that needs docker.
		4. Uninstall docker by running¹:
		      \$ ./uninstall_docker.sh
		5. Remove all copies of docker-compose by running¹:
		      \$ ./uninstall_docker-compose.sh
		6. Reboot.

		That gives you a clean slate. The best way to reinstall docker and
		docker-compose is to run the '04_setup.sh' script²:

		   \$ /boot/scripts/04_setup.sh

		¹ script is in the PiBuilder 'scripts/helpers' folder
		² script is in the PiBuilder 'scripts' folder

		OBSOLETE

		exit 1

	fi

	# so, there is a docker-compose but it isn't the obsolete version
	# is it the python version?
	if [ $(file "$WHERE" | grep -c "Python script") -gt 0 ] ; then

		# yes!
		cat <<-PYTHONDEL
		Python-based version of docker-compose found.
		Assuming it was installed using pip3.
		Trying to remove it using pip3.
		PYTHONDEL
		PIP_BREAK_SYSTEM_PACKAGES=1 pip3 uninstall -y docker-compose

		# re-try the search for docker-compose
		WHERE=$(which docker-compose)

		# found anything?
		if [ -n "$WHERE" ] ; then
			cat <<-PYTHONDELFAIL
			Attempts to remove the Python-based version of docker-compose seem to
			have failed because docker-compose is still installed. You will need to
			investigate why. The problematic file is $WHERE
			PYTHONDELFAIL
			exit 1
		fi

	else

		# it isn't obsolete and it isn't the python script. Assume it's
		# some version of the modern script - iterate to remove all traces
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
	cat <<-FETCHING
	Attempting to fetch docker-compose from:
	   $COMPOSE_URL
	FETCHING

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
		cat <<-FETCHSUCCESS
		Modern docker-compose installed as $TARGET
		   Identifies as $(docker-compose version)
		Also copied to $BIN_PATH_DIR. You can call it as either:
		   \$ docker-compose version
		or as a plugin - without the hyphen - via:
		   \$ docker compose version
		You can check for later versions at $COMPOSE_HOME
		Docker documentation recommends adding the following to your .profile
		   \$ export DOCKER_BUILDKIT=1
		Reference:
		   https://docs.docker.com/develop/develop-images/build_enhancements/#to-enable-buildkit-builds
		FETCHSUCCESS

	else

		# no! failed. That means TARGET is useless
		rm -f "$TARGET"

		echo "Attempt to download docker-compose failed. Falling back to pip method."
		PIP_BREAK_SYSTEM_PACKAGES=1 pip3 install -U docker-compose

	fi

else

	cat <<-DELFAIL
	Attempts to remove older versions of docker-compose seem to have failed
	because docker-compose is still installed. You will need to investigate
	why. The problematic file is $WHERE
	DELFAIL

	exit 1

fi
