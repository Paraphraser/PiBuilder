#!/usr/bin/env bash

# should not run as root
[ "$EUID" -eq 0 ] && echo "This script should NOT be run using sudo" && exit 1

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

APT_DEPENDENCIES="python3-pip python3-dev python3-virtualenv"
PIP_UNINSTALL="virtualenv ruamel.yaml blessed"
REQUIREMENTS="$HOME/IOTstack/requirements-menu.txt"
VIRTUALENV="$HOME/IOTstack/.virtualenv-menu"

echo -e "\n\nEnsuring apt directories are up-to-date..."
sudo apt update

echo -e "\n\nReinstalling apt dependencies..."
sudo apt reinstall -y $APT_DEPENDENCIES

echo -e "\n\nUninstalling pip dependencies..."
for P in $PIP_UNINSTALL ; do
   sudo pip3 uninstall -y $PIBUILDER_PYTHON_OPTIONS "$P"
   pip3 uninstall -y $PIBUILDER_PYTHON_OPTIONS "$P"
done

echo -e "\n\nSatisfying menu requirements..."
pip3 install -U $PIBUILDER_PYTHON_OPTIONS -r "$REQUIREMENTS"

echo -e "\n\nErasing any pre-existing virtual environment"
# (sudo should not be needed but is used here just in case)
sudo rm -rf "$VIRTUALENV"

echo "Logging-out. You should login and re-run the menu."
kill -HUP "$PPID"

