#!/usr/bin/env sh

# work out where this tool is running
WHERE=$(realpath "$0")
WHERE=$(dirname "$WHERE")

# sense running on macOS
[ "$(uname -s)" == "Darwin" ] && isMacOS=true

# the volume name is
BOOTVOLUME="boot"

# define the source directory
BOOTSOURCE="$WHERE/$BOOTVOLUME"

# this is where the boot volume mounts on macOS
BOOTTARGET="/Volumes/$BOOTVOLUME"

# a general-purpose reporting function
report () {
   if [ $isMacOS ] ; then
      osascript -e "display notification \"$1\" with title \"RPi setup\""
   else
      echo "RPi setup: $1"
   fi
}

# does the boot source exist?
if [ ! -d "$BOOTSOURCE" ] ; then
   report "boot directory not found."
   exit 0
fi

# does the target exist?
if [ ! -d "$BOOTTARGET" ] ; then
   report "boot volume not mounted."
   exit 0
fi

# copy the **contents** of the boot directory to the boot target
cp -aX "$BOOTSOURCE"/* "$BOOTTARGET"

# running macOS ?
if [ $isMacOS ] ; then

   # yes make sure we are not in this volume (it's about to be ejected)
   cd

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

   # eject the volume
   /usr/sbin/diskutil eject "$BOOTTARGET"

else

   report "If you have OS-specific cleanup and ejection routines, put them here"

fi

# declare complete
report "boot volume set up - safe to remove."
