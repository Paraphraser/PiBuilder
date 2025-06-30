#!/usr/bin/env bash

# should not run as root
[ "$EUID" -eq 0 ] && echo "This script should NOT be run using sudo" && exit 1

# the name of this script is
SCRIPT=$(basename "$0")

if [ "$#" -gt 0 ]; then
    echo "Usage: $SCRIPT"
    exit 1
fi

# this script should terminate on errors
set -e

# set defaults but permit overrides by caller
SQLITEYEAR="${SQLITEYEAR:-2025}"
SQLITEVERSION="${SQLITEVERSION:-3500200}"

# path components
SQLITE_LFN="sqlite-autoconf-$SQLITEVERSION"
SQLITE_EXT="tar.gz"

# construct download URL
SQLITEURL="https://www.sqlite.org/$SQLITEYEAR/$SQLITE_LFN.$SQLITE_EXT"
echo "Using $SQLITEURL"
echo "check https://www.sqlite.org/download.html for updates"

# create a directory to download into
DOWNLOAD=$(mktemp -d /tmp/sqlite.download.XXXXX)

echo "Note: this script terminates on errors. If the script succeeds"
echo "      it will install SQLite3, clean up and print 'Success!'"
echo "      If you do NOT see that message then the intermediate files"
echo "      will be found in $DOWNLOAD. A 'make clean' may help."

# move into that directory
cd "$DOWNLOAD"

# define the download name
LFN="sqlite.source.tar.gz"

# fetch the source code
wget -O "$LFN" "$SQLITEURL"

# unpack
tar -xzf "$LFN"

# move into the versioned directory
cd "$SQLITE_LFN"

# make the bastard!
echo "Configuring $SQLITEVERSION"
./configure

echo "Building $SQLITEVERSION"
make

echo "Installing $SQLITEVERSION"
sudo make install

echo "Cleaning up"
cd $HOME
rm -rf $DOWNLOAD

echo "Success!"
