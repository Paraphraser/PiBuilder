#!/usr/bin/env bash

#
# Removes as many installations of docker-compose as it can find:
#
# This script can be invoked as:
#
#  ./uninstall_docker-compose.sh
#

# should not run as root
[ "$EUID" -eq 0 ] && echo "This script should NOT be run using sudo" && exit 1

# support user renaming of script
SCRIPT=$(basename "$0")

TARGET="docker-compose"
TARGET_PLUGIN="docker-compose-plugin"

# no arguments
if [ "$#" -ne 0 ]; then

    echo "Usage: $SCRIPT"
    exit 1

fi

# only really supported for Linux (intended for Raspbian but not enforced)
if [ "$(uname -s)" !=  "Linux" -o -z "$(which apt)" -o -z "$(which pip3)" ] ; then

   echo "This script should only be run on Linux systems supporting 'apt' and 'pip3'."
   exit 1

fi

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

# step 1 - remove any versions installed via apt
echo "Attempting to remove any versions managed by 'apt'"
sudo apt -y remove $TARGET $TARGET_PLUGIN

# step 2 - remove any python versions
echo "Attempting to remove any versions installed by 'pip3'"
sudo pip3 uninstall -y $PIBUILDER_PYTHON_OPTIONS $TARGET
pip3 uninstall -y $PIBUILDER_PYTHON_OPTIONS $TARGET

# candidate directories where modern plugin versions might be installed
read -r -d '' INSTALL_DIRS <<-EOF
	/usr/local/bin
	/usr/libexec/docker/cli-plugins
	/usr/local/libexec/docker/cli-plugins
	/usr/lib/docker/cli-plugins
	/usr/local/lib/docker/cli-plugins
	/root/.docker/cli-plugins
	$HOME/.docker/cli-plugins
EOF

# step 3 - remove any plugin-style versions
echo "Searching for plugin-style versions"
for DIR in $INSTALL_DIRS ; do
  CANDIDATE="$DIR/$TARGET"
  if [ -e "$CANDIDATE" -o -L "$CANDIDATE" ] ; then
     echo "  removing $CANDIDATE"
     sudo rm -f "$CANDIDATE"
  fi
done

# step 4 - remove anything not captured by the above
echo "Searching for any other versions in the PATH"
for CANDIDATE in $(which -a $TARGET) ; do
  echo "  removing $CANDIDATE"
  sudo rm -f "$CANDIDATE"
done

echo "With any luck, all versions of $TARGET have been nuked."
echo "If you also un-installed docker, you MUST now reboot."
