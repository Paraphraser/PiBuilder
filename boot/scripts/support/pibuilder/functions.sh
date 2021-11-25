# this file is "sourced" in all build scripts.


# a function to handle installation of a list of packages done ONE AT
# A TIME to reduce failure problems resulting from the all-too-frequent
#  Failed to fetch http://raspbian.raspberrypi.org/raspbian/pool/main/z/zip/zip_3.0-11_armhf.deb
#   Unable to connect to raspbian.raspberrypi.org:http: [IP: 93.93.128.193 80]

install_packages() {

   # declare nothing to retry
   unset RETRIES
   
   # iterate the contents of the file argument
   for PACKAGE in $(cat "$1") ; do

      # attempt to install the package
      sudo apt install -y "$PACKAGE"

      # did the installation succeed or is something playing up?
      if [ $? -ne 0 ] ; then

         # the installation failed - does a retry list exist?
         if [ -z "$RETRIES" ] ; then

            # no! create the file
            RETRIES="$(mktemp -p /dev/shm/)"

         fi

         # add a manual retry
         echo "sudo apt install -y $PACKAGE" >>"$RETRIES"

         # report the event
         echo "PACKAGE INSTALL FAILURE - retry $PACKAGE by hand"

      fi

   done

   # any retries?
   if [ ! -z "$RETRIES" ] ; then

      # yes! bung out the list
      echo "Some base packages could not be installed. This is usually"
      echo "because of some transient problem with APT."
      echo "Retry the errant installations listed below by hand, and"
      echo "then re-run $SCRIPT"
      cat "$RETRIES"
      exit -1

   fi

}


# a function to check whether OS version conditions apply.
# Example:
#   is_running_raspbian buster
# returns true if and only if:
# 1. /etc/os-release exists
# 2. the OS identifies as "raspbian"
# 3. the version codename matches the expected argument in $1

is_running_raspbian() {
   if [ \
      -e "/etc/os-release" \
      -a $(grep -c "^ID=raspbian" /etc/os-release) -gt 0 \
      -a $(grep -c "^VERSION_CODENAME=$1" /etc/os-release) -gt 0 \
   ] ; then
      return 0
   fi
   return 1
}


# a function to find a supporting file or folder proposed in the $1
# parameter.
#
# Parameter $1:
# 1. Paths passed in $1 are expected to begin with a "/" but this is
#    not checked and its omission will lead to undefined results.
#    The leading "/" implies "/boot/scripts/support". This scheme
#    allows for constructs like:
#       TARGET="/etc/rc.local"
#       if PATCH="$(supporting_file "$TARGET.patch")" ; then
#          echo "Patching $TARGET"
#          sudo patch -bfn -z.bak -i "$PATCH" "$TARGET"
#       fi
#    In this example, the $1 argument will expand to:
#       /boot/scripts/support/etc/rc.local.patch
# 2. Paths are mostly files but the scheme will also work for folders.
#
# The function yields:
# 1. A reply string (a path)
# 2. A result code where:
#      0 = success = OK to use this file or folder
#      1 = fail = do not use this file or folder
#
# Example reply strings:
#   supporting_file "/pibuilder-options" will return either:
#     /boot/scripts/support/pibuilder-options@host
#     /boot/scripts/support/pibuilder-options
#
#   supporting_file "/etc/rc.local.patch" will return either:
#     /boot/scripts/support/etc/rc.local.patch@host
#     /boot/scripts/support/etc/rc.local.patch
#
# The result code will be 0 (success) if the reply string points to:
# a. a folder which contains at least one visible file; OR
# b. a file of non-zero length.
#
# The result code will be 1 (fail) if the reply string points to:
# a. a file system component that does not exist; OR
# b. a folder which is empty or only contains invisible files; OR
# c. a file which is zero length.

supporting_file() {

   # test for a machine-specific version of the requested item
   local RETURN_PATH="${SUPPORT}${1}@${HOSTNAME}"

   # does a machine-specific version of the requested item exist?
   if [ ! -e "$RETURN_PATH" ] ; then

      # no! fall back to a generic version
      RETURN_PATH="${SUPPORT}${1}"

   fi

   # return whichever path emerges
   echo "$RETURN_PATH"

   # is it a folder?
   if [ -d "$RETURN_PATH" ] ; then

      # yes! a visibly non-empty folder is acceptable
      [ -n "$(ls -1 "$RETURN_PATH")" ] && return 0

   else

      # no! a non-zero-length file is acceptable
      [ -s "$RETURN_PATH" ] && return 0

   fi

   # otherwise indicate "do not use"
   return 1

}


# a function to find a patch file for the supplied $1 argument and
# attempt to apply it if one exists.
#
# Parameter $1: path to the file to be patched (eg /etc/rc.local) will
#               look for either:
#                  /boot/scripts/support/etc/rc.local.patch@host
#                  /boot/scripts/support/etc/rc.local.patch
# Parameter $2: a comment string describing the patch
#
# Return code = 0 if the patch is found and can be applied, 1 otherwise.
#
# Outputs comments indicating whether the patch was found and applied,
# found and not applied successfully, or not found.
#
# Can be called in two forms:
# 1.  try_patch "/etc/rc.local" "launch isc-dhcp-fix.sh at boot"
# 2.  if try_patch "/etc/rc.local" "launch isc-dhcp-fix.sh at boot" ; then
#        --some conditional actions here--
#     fi

try_patch() {

   local PATCH

   # does a patch file exist for the target in $1 ?
   if PATCH="$(supporting_file "$1.patch")" ; then

      # yes! try to apply the patch
      sudo patch -bfn -z.bak -i "$PATCH" "$1"

      # did the patch succeed?
      if [ $? -eq 0 ] ; then

         # yes! report success
         echo "[PATCH] $PATCH applied to $1 - $2"

         # shortstop return - success
         return 0

      else

         # no! report failure
         echo "[PATCH] FAILED to apply $PATCH to $1 - $2"

      fi

   else

      # no patch found
      echo "[PATCH] no patch $PATCH found for $1 - $2"

   fi

   return 1

}


# a function to "source":
# 1. the pibuilder-options script
# 2. a prolog based on the script name. For example:
#       01_setup.sh
#    searches /boot/scripts/support/pibuilder/prologs for
#       01_setup.sh@host then 01_setup.sh
# In each case, a file is only sourced if it exists and has non-zero
# file length.

run_pibuilder_prolog() {

   local IMPORT

   # import user options if they exist
   if IMPORT="$(supporting_file "/pibuilder/options.sh")" ; then
      echo "Importing user options from $IMPORT"
      . "$IMPORT"
   fi

   # run a prolog if it exists
   if IMPORT="$(supporting_file "/pibuilder/prologs/$SCRIPT")" ; then
      echo "Executing commands in $IMPORT"
      . "$IMPORT"
   fi

}


# a function to "source" an epilog based on the script name. For
# example:
#    01_setup.sh
# searches /boot/scripts/support/pibuilder/epilogs for
#    01_setup.sh@host then 01_setup.sh
# The file is only sourced if it exists and has non-zero file length.

run_pibuilder_epilog() {

   local IMPORT

   # run epilog if it exists
   if IMPORT="$(supporting_file "/pibuilder/epilogs/$SCRIPT")" ; then
      echo "Executing commands in $IMPORT"
      . "$IMPORT"
   fi

}
