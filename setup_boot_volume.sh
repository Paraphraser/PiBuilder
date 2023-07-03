#!/usr/bin/env bash

# the name of this script is
SCRIPT=$(basename "$0")

# work out where this tool is running. Logic:
# 1. $0 is the path to the script.
# 2. realpath converts $0 to absolute path
# 3. dirname removes last path component (ie the script name), leaving
#    the path to the folder containing the script.
WHERE=$(realpath "$0")
WHERE=$(dirname "$WHERE")

# define the source directory
BOOTSOURCE="$WHERE/boot"

# assume no need to display usage statement
USAGE=0

# sense running on macOS
[ "$(uname -s)" == "Darwin" ] && isMacOS=true

# how many script arguments?
case "$#" in

  0 )
    if [ $isMacOS ] ; then
       [ -d "/Volumes/boot" ] && BOOTTARGET="/Volumes/boot"
       [ -d "/Volumes/bootfs" ] && BOOTTARGET="/Volumes/bootfs"
    else
       USAGE=1
    fi
    ;;

  1 )
    BOOTTARGET="$1"
    ;;

  *)
    USAGE=1
    ;;

esac

if [ $USAGE -ne 0 ] ; then
   echo "Usage: $SCRIPT path_to_mountpoint_of_raspbian_boot_partition"
   exit 1
fi

# does the boot source exist?
if [ ! -d "$BOOTSOURCE" ] ; then
   echo "boot directory not found in same folder as $SCRIPT."
   exit 0
fi

# does the target exist?
if [ ! -d "$BOOTTARGET" ] ; then
   echo "boot volume not mounted."
   exit 0
fi

# running macOS ?
if [ $isMacOS ] ; then

   # copy the **contents** of the boot directory to the boot target
   # -R is recursive, -X excludes extended attributes (resource forks)
   cp -RX "$BOOTSOURCE"/* "$BOOTTARGET"

   # tell spotlight to ignore the volume
   touch "$BOOTTARGET/.metadata_never_index"

   # turn spotlight off for this volume (it might be on already)
   mdutil -i off "$BOOTTARGET"

   # erase any spotlight metadata stores that might have been built
   mdutil -E "$BOOTTARGET"

   # kill any .DS_Store files
   find "$BOOTTARGET" -name ".DS_Store" -delete

   # next, kill any resource-fork shadows
   find "$BOOTTARGET" -name "._*" -delete

   # remove other macOS-specific stuff
   rm -rf \
      "$BOOTTARGET/.Trashes/" \
      "$BOOTTARGET/.fseventsd/" \
      "$BOOTTARGET.Spotlight-V100/"

   # try to unmount the volume
   /usr/sbin/diskutil eject "$BOOTTARGET"

   # did the unmount succeed?
   if [ $? -eq 0 ] ; then

      #yes! all done
      echo "boot volume set up - safe to remove."

   else

      #no! warning
      echo "unable to unmount boot volume."

   fi

else

   # copy the **contents** of the boot directory to the boot target
   # -R is recursive
   cp -R "$BOOTSOURCE"/* "$BOOTTARGET"

   # If you have OS-specific cleanup and ejection routines, put them here
   echo "boot volume set up - you can eject it now."

fi
