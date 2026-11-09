#!/usr/bin/env bash

# The purpose of this script is to undo the effect of the companion
# script which converts an IPv4 configuration that was assigned to a
# connection by DHCP to a static form.
#
# Note: the fields which are cleared by this script should be identical
#       to those which are set by the companion "create" script. The
#       result is undefined if the two scripts get out of sync.

# the name of this script is
SCRIPT=$(basename "${0}")

usage () {
	cat <<-USAGE

		Usage: ${SCRIPT} {«options»} «phy»

		       where «phy» is the name of a network interface (eg eth0) and
		       «options» include

		         -? -h --help  to display this usage
		         -n --dry-run  to show but not implement the change

		This script removes a static configuration applied to a connection,
		returning it to DHCP allocation.

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

connection_for_phy () {
      local CONN=$(nmcli -g GENERAL.CONNECTION dev show "${1}" 2>/dev/null)
      echo "${CONN}"
      [ -z "${CONN}" ] && return 1
      return 0
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
			PHY=${1}
		;;

	esac

	# swallow argument
	shift

done

# sense no PHY provided
[ -n "${PHY}" ] || fatal "Missing argument"

# must be able to convert PHY to connection name
CONN=$(connection_for_phy "${PHY}")
[ -n "${CONN}" ] || fatal "no connection for ${PHY}"

# the method for the connection must be manual 
METHOD=$(nmcli -g ipv4.method connection show "${CONN}")
[ "${METHOD}" = "manual" ] || fatal "existing method for ${CONN} is ${METHOD} (must be manual)"

# are we proceeding to implementation?
if [ "${IMPLEMENT}" = "true" ] ; then

	# apply change (the fields being set NULL here MUST be
	# the same as are set by the companion script)
	sudo nmcli connection modify "${CONN}" \
		ipv4.method "auto" \
		ipv4.addresses "" \
		ipv4.gateway "" \
		ipv4.dns "" \
		ipv4.dns-search ""

	# make it stick
	sudo nmcli connection up "${CONN}"

else

	cat <<-DRYRUN

		Would implement the following commands:

		   \$ sudo nmcli connection modify "${CONN}" \\
		         ipv4.method "auto" \\
		         ipv4.addresses "" \\
		         ipv4.gateway "" \\
		         ipv4.dns "" \\
		         ipv4.dns-search ""

		   \$ sudo nmcli connection up "${CONN}"

	DRYRUN

fi