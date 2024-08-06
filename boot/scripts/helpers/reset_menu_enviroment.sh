#!/usr/bin/env bash

# should not run as root
[ "$EUID" -eq 0 ] && echo "This script should NOT be run using sudo" && exit 1

IOTSTACK=${IOTSTACK:-"$HOME/IOTstack"}
IOTSTACK=$(realpath "$IOTSTACK")
APT_DEPENDENCIES="python3-pip python3-dev python3-virtualenv"
PIP_UNINSTALL="virtualenv ruamel.yaml blessed"
REQUIREMENTS="$IOTSTACK/requirements-menu.txt"
VIRTUALENV="$IOTSTACK/.virtualenv-menu"

echo -e "\n\nEnsuring apt directories are up-to-date..."
sudo apt update

echo -e "\n\nReinstalling apt dependencies..."
sudo apt reinstall -y $APT_DEPENDENCIES

echo -e "\n\nUninstalling pip dependencies..."
for P in $PIP_UNINSTALL ; do
   sudo PIP_BREAK_SYSTEM_PACKAGES=1 pip3 uninstall -y "$P"
   PIP_BREAK_SYSTEM_PACKAGES=1 pip3 uninstall -y "$P"
done

echo -e "\n\nSatisfying menu requirements..."
PIP_BREAK_SYSTEM_PACKAGES=1 pip3 install -U -r "$REQUIREMENTS"

echo -e "\n\nErasing any pre-existing virtual environment"
# (sudo should not be needed but is used here just in case)
sudo rm -rf "$VIRTUALENV"

echo "Logging-out. You should login and re-run the menu."
kill -HUP "$PPID"

