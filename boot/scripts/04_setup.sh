#!/usr/bin/env bash

# should not run as root
[ "$EUID" -eq 0 ] && echo "This script should NOT be run using sudo" && exit -1

# the name of this script is
SCRIPT=$(basename "$0")

if [ "$#" -gt 0 ]; then
    echo "Usage: $SCRIPT"
    exit -1
fi

SUPPORT="/boot/scripts/support"

echo "Setting up git (config and ignores)"
cp "$SUPPORT/dot-gitconfig" ~/.gitconfig
cp "$SUPPORT/dot-gitignore_global" ~/.gitignore_global

# un-comment and replace the right hand side if you have a GPG Key ID
# available from keyserver.ubuntu.com
# GPGKEYID=04B9CD3D381B574D

if [ -n "$GPGKEYID" ] ; then

   echo "Importing GPG public key"
   gpg --keyserver hkps://keyserver.ubuntu.com:443 --recv $GPGKEYID

   SOURCE="$SUPPORT/gpg-owner-trust.txt"
   if [ -e "$SOURCE" -a $(grep -v "^#" "$SOURCE" | wc -l) -gt 0 ] ; then
      echo "Setting trust level on GPG public key"
      gpg --import-ownertrust "$SOURCE"
   fi

fi

echo "Setting up ssh"
#
# the way I do this is with a "ssh_setup" script which gets installed
# when the 03_setup.sh script does the "svn checkout" described there.
# It's too hard to summarise everything that "ssh_setup" does. You will
# need to come up with your own solution - which could be as simple as
# just using the same approach used for /etc/ssh (a script to snapshot
# the folder, then complementary lines in 01_setup.sh to unpack the
# archive in the right place at the right time).
#
[[ -x $(which ssh_setup) ]] && ssh_setup

echo "Adding mkdocs support"
pip install -U mkdocs
pip install -U mkdocs-awesome-pages-plugin
pip install -U mkdocs-material

echo "Resetting bash history"
history -c

echo "Should now be ready to restore IOTstack backup."

# kill the parent process
echo "$SCRIPT complete. Logging-out..."
kill -HUP "$PPID"
