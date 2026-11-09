#!/usr/bin/env bash

# the purpose of this script is to make Network Manager connection names
# be the same as Network Manager device names (network PHYs). In other
# words, instead of a PHY of "eth0" being "Wired Connection 1", the
# connection is renamed to "eth0". That way you never have to think
# about the distinction between device and connection names.

# the name of this script is
SCRIPT=$(basename "${0}")

usage () {
	cat <<-USAGE

		Usage: ${SCRIPT} {«options»}

		       where «options» include

		         -? -h --help  to display this usage
		         -n --dry-run  to show but not implement the change

		This script iterates the list of network manager devices (PHYs).
		If the connection name differs from the device name, the connection
		is renamed to be the same as the device.

	USAGE
	exit 1
}

fatal () {
	echo -e "\nError: ${1}" >&2
	usage
}

is_NetworkManager_running () {
   if [ "$(systemctl is-active NetworkManager)" = "active" -a -n "$(which nmcli)" ] ; then
      [ "$(nmcli -t -f RUNNING general)" = "running" ] && return 0
   fi
   return 1
}

# must not be run via sudo
[ "$EUID" -eq 0 ] && fatal "This script must NOT be run using sudo"

# network managed must be running
[ is_NetworkManager_running ] || fatal "Network Manager is not running"

# assume implementation of the generated command
IMPLEMENT=true

# process arguments
while [ $# -gt 0 ] ; do

	case "${1}" in

		"-?" ) ;&
		"-h" ) ;&
		"--help" )
			usage
		;;

		"-n" ) ;&
		"--dry-run" )
			IMPLEMENT=false
		;;

		# assume phy
		*)
			fatal "Unexpected argument: ${1}"
		;;

	esac

	# swallow argument
	shift

done

CHANGES=0

# iterate the device list
nmcli -g device device | while read PHY ; do

	# sense null device name
	[ -z "${PHY}" ] && continue

	# find the connection name for this device
	CONN=$(nmcli -g GENERAL.CONNECTION device show "${PHY}")

	# sense either null connection name or the two already match
	[ -z "${CONN}" -o "${PHY}" = "${CONN}" ] && continue

	if [ "${IMPLEMENT}" = "true" ] ; then

		sudo nmcli connection modify "${CONN}" connection.id "${PHY}"
		sudo nmcli connection up "${PHY}"
	
	else
	
		cat <<-DRYRUN

			Would implement the following commands:

			   \$ sudo nmcli connection modify "${CONN}" \\
					 connection.id "${PHY}"

			   \$ sudo nmcli connection up "${PHY}

		DRYRUN

	fi

	CHANGES=$((CHANGES + 1)) 


done

[ ${CHANGES} -lt 1 ] && echo "No work to do!"
