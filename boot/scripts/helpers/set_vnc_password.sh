#!/usr/bin/env bash

#
# Creates/overwrites /etc/vnc/config.d/common.custom:
#
# This script can be invoked as:
#
#   /set_vnc_password.sh
#

# should not run as root
[ "$EUID" -eq 0 ] && echo "This script should NOT be run using sudo" && exit 1

# support user renaming of script
SCRIPT=$(basename "$0")

# no arguments
if [ "$#" -ne 0 ]; then

    echo "Usage: $SCRIPT"
    exit 1

fi

# initialise the template (file owned by $USER, mode 600)
CUSTOM="$(mktemp)"
cat <<-TEMPLATE >"$CUSTOM"
Encryption=PreferOn
Authentication=VncAuth
Password=
TEMPLATE

# the VNC service is
SERVICE="vncserver-x11-serviced"

# the target file to be created is
TARGET="/etc/vnc/config.d/common.custom"

# the parent directory of the target is
PARENT=$(dirname "$TARGET")

# does the parent directory exist?
if [ -d $PARENT ] ; then

   # yes! prompt for the VNC password
   read -s -p "Enter password for VNC access (first 8 characters significant): " NEW_PASSWORD
   echo ""
   read -s -p "Re-enter password: " CHK_PASSWORD
   echo ""
   if [ ! "$NEW_PASSWORD" = "$CHK_PASSWORD" ] ; then
      echo "Passwords do not match!"
      exit 1
   fi
   
   # set the password into the template (changes ownership to root)
   echo -e "$NEW_PASSWORD\n$NEW_PASSWORD" | sudo vncpasswd -file "$CUSTOM"

   # did that succeed?
   if [ $? -eq 0 ] ; then

      # yes! set appropriate permissions
      sudo chmod 644 "$CUSTOM"

      # move the customised template into place
      echo "Moving $CUSTOM to $TARGET"
      sudo mv "$CUSTOM" "$TARGET"
      echo "$TARGET initialised"

      # is the service running?
      if systemctl is-active "$SERVICE" >/dev/null ; then

         # yes! restart to pick up password change
         echo "$SERVICE is active - restarting now"
         sudo systemctl restart "$SERVICE"

      fi

   fi

else

   # no! that's an underlying misconfiguration
   echo "The directory $PARENT does not exist. This is a problem with"
   echo "your operating system which this script can't fix. Sorry."

fi
