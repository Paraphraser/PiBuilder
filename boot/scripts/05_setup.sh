#!/usr/bin/env bash

# should not run as root
[ "$EUID" -eq 0 ] && echo "This script should NOT be run using sudo" && exit 1

# the name of this script is
SCRIPT=$(basename "$0")

# where is this script is running?
WHERE=$(dirname "$(realpath "$0")")

if [ "$#" -gt 0 ]; then
    echo "Usage: $SCRIPT"
    exit 1
fi

# declare path to support directory and import common functions
SUPPORT="$WHERE/support"
. "$SUPPORT/pibuilder/functions.sh"

# import user options and run the script prolog - if they exist
run_pibuilder_prolog

# SUPPORT_HOME defaults to HOME
SUPPORT_HOME="$HOME"

# does the expected folder exist (eg /boot/scripts/support/home/$USER)?
if [ ! -d "$SUPPORT/$SUPPORT_HOME" ] ; then

   # no! switch to user "pi" instead
   echo "$SUPPORT/$SUPPORT_HOME does not exist - substituting user 'pi'"
   SUPPORT_HOME="/home/pi"

fi

# defaults for profile-handling
DOT_PROFILE_ACTION="${DOT_PROFILE_ACTION:-append}"
DOT_BASHRC_ACTION="${DOT_BASHRC_ACTION:-append}"

# function to handle .profile and .bashrc
# $1 = name of target file (".profile" or ".bashrc")
# $2 = value of control var ("$DOT_PROFILE_ACTION" or "$DOT_BASHRC_ACTION")
handleProfile() {
   local SOURCE
   if SOURCE="$(supporting_file "$SUPPORT_HOME/$1")" ; then
      case "${2,,}" in
         "append" )
            echo "Appending $SOURCE to $1"
            cat "$SOURCE" >>"$HOME/$1"
         ;;
         "replace" )
            echo "Replacing $1 with $SOURCE"
            touch "$HOME/$1"
            mv "$HOME/$1" "$HOME/$1.bak"
            cp "$SOURCE" "$HOME/$1"
         ;;
         *)
            echo "$SOURCE found but profile action = $2"
         ;;
      esac
   else
      echo "No supporting file found for $1 - skipped"
   fi
}

handleProfile ".profile" "$DOT_PROFILE_ACTION"
handleProfile ".bashrc" "$DOT_BASHRC_ACTION"

# create a crontab
TARGET="crontab"
if SOURCE="$(supporting_file "$SUPPORT_HOME/$TARGET")" ; then
   echo "Setting up $TARGET from $SOURCE"
   mkdir ~/Logs
   sed "s|«HOMEDIR»|$HOME|g" "$SOURCE" | crontab
fi

TARGET=".gitconfig"
if SOURCE="$(supporting_file "$SUPPORT_HOME/$TARGET")" ; then
   echo "Installing $TARGET from $SOURCE"
   cp "$SOURCE" "$HOME/$TARGET"
fi

TARGET=".gitignore_global"
if SOURCE="$(supporting_file "$SUPPORT_HOME/$TARGET")" ; then
   echo "Installing $TARGET from $SOURCE"
   cp "$SOURCE" "$HOME/$TARGET"
fi

TARGET=".config/rclone/rclone.conf"
if SOURCE="$(supporting_file "$SUPPORT_HOME/$TARGET")" ; then
   echo "Installing configuration file for rclone from $SOURCE"
   mkdir -p $(dirname "$HOME/$TARGET")
   cp "$SOURCE" "$HOME/$TARGET"
fi

TARGET=".config/iotstack_backup/config.yml"
if SOURCE="$(supporting_file "$SUPPORT_HOME/$TARGET")" ; then
   echo "Installing configuration file for iotstack_backup from $SOURCE"
   mkdir -p $(dirname "$HOME/$TARGET")
   cp "$SOURCE" "$HOME/$TARGET"
fi

TARGET="/etc/docker/daemon.json"
if SOURCE="$(supporting_file "$TARGET")" ; then
   echo "Installing $SOURCE"
   sudo touch "$TARGET"
   sudo cp "$SOURCE" "$TARGET"
fi

# run the script epilog if it exists
run_pibuilder_epilog

echo "Resetting bash history"
history -c

echo "Should now be ready to run IOTstack menu or restore IOTstack backup."

# kill the parent process
echo "$SCRIPT complete. Logging-out..."
kill -HUP "$PPID"
