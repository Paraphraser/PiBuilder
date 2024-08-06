#!/usr/bin/env bash

# Expects either one or two arguments
#   $1 is a required path to locales.conf
#   $2 is an optional path to the file to be modified which defaults
#      to /etc/locale.gen
#
# locales.conf is expected to be formatted as a series of left-aligned
# lines:
#
#    [enable]
#    locale name
#    ...
#    [disable]
#    locale name
#    ...
#
# Blank lines and lines beginning with # are ignored.
# More documentation is available in the default locales.conf file.
#
# Exit conditions:
#   0 = $2 will have been patched and $2.bak will exist so it is
#       appropriate for the caller to regenerate locales.
#   1 = parsing #1 didn't produce any editing instructions (which is
#       what happens with the default locales.conf). The caller
#       can interpret this as meaning "normal exit but locales do not
#       need to be regenerated.""
#   2 = either a parameter error or either/both the files specified
#       by the parameters can't be found.

# support script renaming
SCRIPT=$(basename "$0")

# check arguments
if [ $# -eq 0 -o $# -gt 2 ] ; then
   echo "Usage: $SCRIPT path/to/locale.conf {/etc/locale.gen}"
   exit 2
fi

# extract arguments
CONFILE=${1}
GENFILE=${2:-/etc/locale.gen}

# verify both files exist
for F in "$CONFILE" "$GENFILE" ; do
   if [ ! -f "$F" ] ; then
      echo "Note: expected environment does not exist for $SCRIPT - $F"
      exit 2
   fi
done

# assume [enable] mode
MODE="[enable]"

# construct a temporary file to hold the edits
EDITS="$(mktemp)"

# state intention
echo "$SCRIPT - generating editing instructions from $CONFILE:"

# process the configuration file
grep -v -e "^#" -e "^[[:space:]]*$" "$CONFILE" | while read LINE ; do

   # is it one of the defined directives?
   if [ "$LINE" = "[enable]" -o "$LINE" = "[disable]" ] ; then

      # yes! move to the required mode
      MODE="$LINE"

   else

      # no! assume a locale and handle according to mode
      case "$MODE" in
      
         "[disable]" )
            # generate sed command to disable all instances where
            # this locale is enabled
            echo "  $LINE - will be disabled"
            echo "s/^$LINE/# $LINE/g" >>"$EDITS"
         ;;
         
         "[enable]" )
         
            # is the locale already active?
            if [ $(grep -c -e "^$LINE" "$GENFILE") -eq 0 ] ; then

               # no! generate sed command to enable a disabled locale
               echo "  $LINE - will be enabled"
               echo "s/^# *$LINE/$LINE/g" >>"$EDITS"

            else

               # yes! no need to do it multiple times
               echo "  $LINE - already enabled - skipping"

            fi

         ;;
         
         *)
         ;;
         
      esac

   fi

done

# assume abnormal exit
EXIT_CODE=1

# were any commands generated?
if [ -s "$EDITS" ] ; then

   # yes! is the file writeable by the current user?
   if [ -w "$GENFILE" ] ; then

      # yes! so there is work that can be done
      echo "$SCRIPT - applying editing instructions to $GENFILE"

      # yes! perform edits with user permissions
      sed -i.bak -f "$EDITS" "$GENFILE"

      # signal job done
      EXIT_CODE=0

   else

      echo "$SCRIPT - insufficient privileges to edit $GENFILE (use sudo)"

   fi

else

   # no! so there is no work to do
   echo "$SCRIPT - no editing instructions found - $GENFILE left unchanged"

fi

# clean up
rm "$EDITS"

echo "$SCRIPT - finished with exit code $EXIT_CODE"

# return a sensible status so the caller knows what to do next
exit $EXIT_CODE
