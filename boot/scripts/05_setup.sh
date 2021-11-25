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

TARGET="$HOME/.gitconfig"
if SOURCE="$(supporting_file "$TARGET")" ; then
   echo "Installing $TARGET from $SOURCE"
   cp "$SOURCE" "$TARGET"
fi

TARGET="$HOME/.gitignore_global"
if SOURCE="$(supporting_file "$TARGET")" ; then
   echo "Installing $TARGET from $SOURCE"
   cp "$SOURCE" "$TARGET"
fi

echo "Adding mkdocs support"
pip install -U mkdocs
pip install -U mkdocs-awesome-pages-plugin
pip install -U mkdocs-material

# run the script epilog if it exists
run_pibuilder_epilog

echo "Resetting bash history"
history -c

echo "Should now be ready to run IOTstack menu or restore IOTstack backup."

# kill the parent process
echo "$SCRIPT complete. Logging-out..."
kill -HUP "$PPID"
