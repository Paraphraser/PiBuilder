#!/usr/bin/env bash

case "$(uname -s)" in

  "Linux")
    THISHOST="$HOSTNAME"
    ;;

  "Darwin")
    THISHOST="${HOSTNAME%%.*}"
    if [ -z "$THISHOST" ] ; then
       echo "Running macOS (Darwin) but FQDN may not be set"
    fi
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

BACKUPSOURCE="/etc/ssh"
SSHBACKUPTARGZ="./etc-ssh-backup.tar.gz@$RUNTAG"

if [ -d "$BACKUPSOURCE" ] ; then

   # create the file (to assign permissions)
   touch "$SSHBACKUPTARGZ"

   # run the backup
   echo "Supply admin password if requested"
   sudo tar -czf "$SSHBACKUPTARGZ" -C "$BACKUPSOURCE" .

else

   echo "$BACKUPSOURCE does not seem to exist"

fi
