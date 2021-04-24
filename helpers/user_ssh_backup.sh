#!/usr/bin/env bash

case "$(uname -s)" in

  "Linux")
    THISHOST="$HOSTNAME"
    ;;

  "Darwin")
    THISHOST="${HOSTNAME%%.*}"
    ;;

  *)
    echo "Running unsupported operating system"
    exit -1
    ;;

esac

# optional first parameter sets runtag
RUNTAG=${1:-$THISHOST}

if [ -z "$RUNTAG" ] ; then

   echo "An appropriate runtag can't be determined from the hostname"
   echo "(The hostname may not be set)"
   echo "Try again but pass the name for this host as a parameter"
   exit -1
   
fi

BACKUPSOURCE="$HOME/.ssh"
SSHBACKUPTARGZ="$HOME/$USER@$RUNTAG.ssh-backup.tar.gz"

if [ -d "$BACKUPSOURCE" ] ; then

   # create the file (to assign permissions)
   touch "$SSHBACKUPTARGZ"

   # run the backup
   tar -czf "$SSHBACKUPTARGZ" -C "$BACKUPSOURCE" .

else

   echo "$BACKUPSOURCE does not seem to exist"

fi
