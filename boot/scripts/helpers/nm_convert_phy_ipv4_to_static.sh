#!/usr/bin/env bash

# The purpose of this script is to convert an IPv4 configuration that
# was assigned to a connection by DHCP to a static form.
#
# Any or all of the connection fields being set during the conversion
# can be overridden using environment variables.
#
# Note: the fields which are set by this script should be reset to
#       null by the companion "restore" script. The result is undefined
#       if the two scripts get out of sync.

# the name of this script is
SCRIPT=$(basename "${0}")

usage () {
	cat <<-USAGE

		Usage: ${SCRIPT} {«options»} «phy»

		       where «phy» is the name of a network interface (eg eth0) and
		       «options» include

		         -? -h --help  to display this usage
		         -n --dry-run  to show but not implement the change

		This script essentially solidifies the existing dynamic configuration
		allocated to the network interface by DHCP. You can use environment
		variables to override particular settings:

		       NM_IP_CIDR= the IPv4 address of the interface in CIDR form
		                   (eg "192.128.1.10/24")
		       NM_GATEWAY= the IPv4 address of the default gateway (router)
		                   (eg "192.168.1.1")
		   NM_DNS_SERVERS= at least one DNS server IPv4 address
		                   (eg "127.0.0.1,192.168.1.50,8.8.8.8")
		   NM_DNS_DOMAINS= at least one DNS search domain
		                   (eg "my.home.arpa")

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

# the method for the connection must be auto 
METHOD=$(nmcli -g ipv4.method connection show "${CONN}")
[ "${METHOD}" = "auto" ] || fatal "existing method for ${CONN} is ${METHOD} (must be auto)"

# settings that can be overridden
NM_IP_CIDR=${NM_IP_CIDR:-$(nmcli -g "IP4.ADDRESS" connection show "${CONN}")}
NM_GATEWAY=${NM_GATEWAY:-$(nmcli -g "IP4.GATEWAY" connection show "${CONN}")}
NM_DNS_DOMAINS=${NM_DNS_DOMAINS:-$(nmcli -g "IP4.DOMAIN" connection show "${CONN}")}
NM_DNS_SERVERS=${NM_DNS_SERVERS:-$(nmcli -g IP4.DNS conn show wlan0 | sed -e "s/ | /,/g")}

# verify all required fields exist
[ -n "${NM_IP_CIDR}" ] || fatal "No DHCP-allocated address could be found for ${PHY}"
[ -n "${NM_GATEWAY}" ] || fatal "No DHCP-allocated default gateway address could be found for ${PHY}"
[ -n "${NM_DNS_DOMAINS}" ] || fatal "No DHCP-allocated search domain could be found for ${PHY}"
[ -n "${NM_DNS_SERVERS}" ] || fatal "No DHCP-allocated DNS servers could be found for ${PHY}"

# are we proceeding to implementation?
if [ "${IMPLEMENT}" = "true" ] ; then

	# apply change
	sudo nmcli connection modify "${CONN}" \
		ipv4.method "manual" \
		ipv4.addresses "${NM_IP_CIDR}" \
		ipv4.gateway "${NM_GATEWAY}" \
		ipv4.dns "${NM_DNS_SERVERS}" \
		ipv4.dns-search "${NM_DNS_DOMAINS}"

	# make it stick
	sudo nmcli connection up "${CONN}"

else

	cat <<-DRYRUN

		Would implement the following commands:

		   \$ sudo nmcli connection modify "${CONN}" \\
		         ipv4.method "manual" \\
		         ipv4.addresses "${NM_IP_CIDR}" \\
		         ipv4.gateway "${NM_GATEWAY}" \\
		         ipv4.dns "${NM_DNS_SERVERS}" \\
		         ipv4.dns-search "${NM_DNS_DOMAINS}"

		   \$ sudo nmcli connection up "${CONN}"

	DRYRUN

fi