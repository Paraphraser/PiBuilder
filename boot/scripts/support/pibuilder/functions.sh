# this file is "sourced" in all build scripts.


# a function to handle installation of a list of packages done ONE AT
# A TIME to reduce failure problems resulting from the all-too-frequent
#  Failed to fetch http://raspbian.raspberrypi.org/raspbian/pool/main/z/zip/zip_3.0-11_armhf.deb
#   Unable to connect to raspbian.raspberrypi.org:http: [IP: 93.93.128.193 80]
# Takes two arguments - first is packages list, second is exit code on
# failure.

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

      # set the scene
      echo "Some base packages could not be installed. This is usually"
      echo "because of some transient problem with APT."
      echo ""

      # are the dependencies mandatory
      if [ $2 -eq 1 ] ; then

         # yes! bung out the list and abort
         echo "Retry the errant installations listed below by hand, and"
         echo "then re-run $SCRIPT."

      else

         # no! bung out the list and continue
         echo "The errant installations listed below are NOT essential"
         echo "for either PiBuilder or IOTstack. This script will continue"
         echo "without these dependencies but you should probably try"
         echo "installing them by hand after you have finished running"
         echo "PiBuilder."

      fi

      echo "------------------------------------------------------------"
      cat "$RETRIES"
      echo "------------------------------------------------------------"
      exit $2

   fi

}


# a function to return the OS distribution
# Example:
#   running_OS_distro
# returns a string containing the OS distro (eg debian) if and only if
# 1. /etc/os-release exists
# 2. /etc/os-release defines the ID variable
# 3. ID is non-null
# Otherwise returns "unknown" and sets exit code 1

running_OS_distro() {
   if [ -e "/etc/os-release" ] ; then
      . "/etc/os-release"
      if [ -n "$ID" ] ; then
         echo "$ID"
         return 0
      fi
   fi
   echo "unknown"
   return 1
}


# a function to check whether OS distro conditions apply.
# Example:
#   is_running_OS_distro debian
# returns true if and only if the result of running_OS_distro matches
# the expected argument in $1, otherwise returns false

is_running_OS_distro() {
   if [ "$(running_OS_distro)" = "$1" ] ; then
      return 0
   fi 
   return 1
}


# a function to return the OS version name
# Example:
#   running_OS_release
# returns a string containing the OS name (eg bullseye) if and only if
# 1. /etc/os-release exists
# 2. /etc/os-release defines the VERSION_CODENAME variable
# 3. VERSION_CODENAME is non-null
# Otherwise returns "unknown" and sets exit code 1

running_OS_release() {
   if [ -e "/etc/os-release" ] ; then
      . "/etc/os-release"
      if [ -n "$VERSION_CODENAME" ] ; then
         echo "$VERSION_CODENAME"
         return 0
      fi
   fi
   echo "unknown"
   return 1
}


# a function to check whether OS version conditions apply.
# Example:
#   is_running_OS_release buster
# returns true if and only if the result of running_OS_release matches
# the expected argument in $1, otherwise returns false

is_running_OS_release() {
   if [ "$(running_OS_release)" = "$1" ] ; then
      return 0
   fi 
   return 1
}


# a function to return the OS build level
# Example:
#   running_OS_build
# returns a string representing the common name used to refer to
# distinctive flavours of build
running_OS_build() {

   # determine the build stage
   local ISSUE="/boot/issue.txt"
   [ ! -f "$ISSUE" ] && ISSUE="/boot/firmware/issue.txt"
   [ ! -f "$ISSUE" ] && echo "unknown" && return -1
   local BUILDSTAGE=$(tail -1 "$ISSUE" | cut -d "," -f 4 | tr -d "[:space:]")

   # vector on answer
   case "$BUILDSTAGE" in

      "stage1" )
         echo "minimal"
         ;;

      "stage2" )
         echo "lite"
         ;;

      "stage3" )
         echo "desktop"
         ;;

      "stage4" )
         echo "normal"
         ;;

      "stage5" )
         echo "full"
         ;;

      *)
         echo "unknown"
         return -1
         ;;

   esac

}


# a function to check whether the running OS was based on a particular
# build stage. Example:
#   is_running_OS_build lite
# returns true if and only if the result of running_OS_build matches
# the expected argument in $1, otherwise returns false
is_running_OS_build() {
   if [ "$(running_OS_build)" = "$1" ] ; then
      return 0
   fi
   return 1
}


# a function to check whether the system as a whole is 64-bit.
# That means both a 64-bit kernel and 64-bit-capable user space.
# Example:
#   is_running_OS_64bit
# returns true if and only if:
# 1. the kernel identifies as aarch64
# 2. lscpu suggests the capability to run in both 32- and 64-bit modes

is_running_OS_64bit() {
   if [ "$(uname -m)" = "aarch64" -a $(lscpu | grep -c "32-bit, 64-bit") -eq 1 ] ; then
      return 0
   fi
   return 1
}


# a function to check if running on a Raspberry Pi. There may be better
# ways of doing this but the presence of /usr/bin/raspi-config seems to
# be a reasonable proxy
is_raspberry_pi() {
   if [ -x "/usr/bin/raspi-config" ] ; then
      return 0
   fi
   return 1
}

# a function to determine whether NetworkManager is running.
# Example:
#   is_NetworkManager_running
# Returns true is and only if:
# 1. systemctl thinks the NetworkManager service is active
# 2. the nmcli command is available in the search path
# 3. the nmcli command thinks NetworkManager is running
is_NetworkManager_running () {
   if [ "$(systemctl is-active NetworkManager)" = "active" -a -n "$(which nmcli)" ] ; then
      [ "$(nmcli -t -f RUNNING general)" = "running" ] && return 0
   fi
   return 1
}

# a function to find a file which can either be in /boot/firmware or
# /boot. Only tested for config.txt and cmdline.txt.
#
# Parameter $1 : filename
# If /boot/firmware/$1 exists that path is returned.
# else if /boot/$1 exists that path is returned
# else a null string is returned. Note that a null string will fail
# any subsequent path check
path_to_pi_boot_file() {
   local CANDIDATE="/boot/firmware/$1"
   if [ ! -f "$CANDIDATE" ] ; then
      CANDIDATE="/boot/$1"
   fi
   if [ -f "$CANDIDATE" ] ; then
      echo "$CANDIDATE"
   else
      echo ""
   fi
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
# Parameter $3: optional. If true, returm success even if patch fails
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

   # does the target of the patch exist?
   if [ ! -f "$1" ] ; then

      # no! report
      echo "[PATCH] can't be attempted - $1 does not exist"

      # shortstop return
      [ "$3" = "true" ] && return 0 || return 1

   fi

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

         # return success if errors should be ignored
         [ "$3" = "true" ] && return 0

      fi

   else

      # no patch found
      echo "[PATCH] no patch found for $1"

   fi

   return 1

}


# a function to find a patch directory for the supplied $1 argument and,
# if one exists, attempt to merge its contents with the implied target
#
# Parameter $1: path to the folder to be merged (eg /etc/ppp) will
#               look for either:
#                  /boot/scripts/support/etc/ppp@host
#                  /boot/scripts/support/etc/ppp
# Parameter $2: a comment string describing the merge
#
#  Return code: if BOTH the source and target indicated by $1 exist AND
#               are directories then:
#               1. rsync is invoked to merge the two directories; an
#               2. the return code is rsync's return code.
#               Otherwise 1 if either/both the source and target
#               do not exist or are not directories.
#
# Outputs comments indicating whether the patch was found and applied,
# found and not applied successfully, or not found.
#
# Can be called in two forms:
# 1.  try_merge "/etc/ppp" "merging /etc/ppp directors"
# 2.  if try_merge "/etc/ppp" "merging /etc/ppp directors" ; then
#        --some conditional actions here--
#     fi

try_merge() {

   local MERGEDIR

   # does file-system object exist for the target in $1 ?
   if MERGEDIR="$(supporting_file "$1")" ; then

      echo "[MERGE] $1 - $2"

      # yes! are it and the target both directories?
      if [ -d "$MERGEDIR" -a -d "$1" ] ; then

         # yes! supporting_file() has already determined that the
         # source directory is not empty so try to merge
         echo "[MERGE] calling rsync to perform non-overwriting merge"

         # merge without overwriting. The trailing "/" on MERGEDIR is
         # required. The filtering gets rid of macOS artifacts.
         sudo rsync -rv --ignore-existing --exclude=".DS_Store" --exclude="._*" "$MERGEDIR"/ "$1"

         # return rsync's result code
         return $?

      fi

      echo "[MERGE] skipped - both $MERGEDIR and $1 must be directories"

   else

      # no source directory found
      echo "[MERGE] skipped - no non-empty merge directory found for $1"

   fi

   return 1

}


# a function to find a sed file for the supplied $1 argument and
# attempt to apply it if one exists.
#
# Parameter $1: path to the file to be patched (eg /etc/dphys-swapfile)
#               will look for either:
#                  /boot/scripts/support/etc/dphys-swapfile.sed@host
#                  /boot/scripts/support/etc/dphys-swapfile.sed
# Parameter $2: a comment string describing the editing to be done
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

try_edit() {

   local SED SEDBACK

   # does the target of the patch exist?
   if [ ! -f "$1" ] ; then

      # no! report
      echo "[EDIT] can't be attempted - $1 does not exist"

      # shortstop return
      return 1

   fi

   # does a patch file exist for the target in $1 ?
   if SED="$(supporting_file "$1.sed")" ; then

      # yes! the backup file (if it gets created) will be
      SEDBACK="$1.pibuilder.bak"

      # try to apply the edits
      sudo sed -i.pibuilder.bak -f "$SED" "$1"

      # did sed complete normally?
      if [ $? -eq 0 ] ; then

         # yes! has the backup file been created?
         if [ -f "$SEDBACK" ] ; then

            # yes! do the original and backup compare same?
            if cmp -s "$1" "$SEDBACK" ; then

               # yes! this implies the edits did nothing
               echo "[EDIT] no changes made by applying $SED to $1 - $2"

               # remove the backup file
               sudo rm "$SEDBACK"

            else

               # no! this implies the edits made a change
               echo "[EDIT] $SED applied to $1 - $2"

               # the interim backup file should become permanent .bak
               sudo mv "$SEDBACK" "$1.bak"

               # shortstop return - success
               return 0

            fi

         else

            # no! the absense of a backup file means the edit failed
            echo "[EDIT] FAILED to apply $SED to $1 - $2"

         fi

      else

         # no! cleanup the backup file if it got created
         sudo rm -f "$SEDBACK"

         # explain
         echo "[EDIT] sed REFUSED to edit $1 - $2"
         echo "       ($SED may contain invalid commands)"

      fi

   else

      # no patch found
      echo "[EDIT] no edits found for $1"

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

   echo "Note: pip3 installs will bypass externally-managed environment check"

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
