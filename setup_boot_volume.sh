#!/usr/bin/env sh

# work out where this tool is running
WHERE=$(realpath "$0")
WHERE=$(dirname "$WHERE")

# the volume name is
BOOTVOLUME="boot"

# define the source and target
BOOTSOURCE="$WHERE/$BOOTVOLUME"
BOOTTARGET="/Volumes/$BOOTVOLUME"

# does the boot source exist?
if [ ! -d "$BOOTSOURCE" ] ; then
   osascript -e 'display notification "boot directory not found." with title "RPi setup"'
   exit 0
fi

# does the target exist?
if [ ! -d "$BOOTTARGET" ] ; then
   osascript -e 'display notification "boot volume not mounted." with title "RPi setup"'
   exit 0
fi

# make sure the boot source doesn't have any DSStores
find "$BOOTSOURCE" -name .DS_Store -delete

# copy the **contents** of the boot directory to the boot target
cp -aX "$BOOTSOURCE"/* "$BOOTTARGET"

# now eject it
eject__VolumeWithPrejudice $BOOTVOLUME

# declare complete
osascript -e 'display notification "boot volume set up." with title "RPi setup"'
