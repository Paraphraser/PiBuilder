#!/usr/bin/env bash

# $1 = new name of host (required)
# $2 = domain name to use (optional)

# must run as root
[ "$EUID" -ne 0 ] && echo "This script MUST be run using sudo" && exit 1

# the name of this script is
SCRIPT=$(basename "$0")

# check parameters
if [ $# -lt 1 -o $# -gt 2 ] ; then
	echo "Usage: sudo $SCRIPT hostname {domain}"
	exit 1
fi

# sanitise hostname (only lower-case letters, digits, hyphens)
# (-dc = delete any characters in the complement of the set)
HNAME=$(echo "$1" | tr -dc '[:alnum:]-' | tr '[:upper:]' '[:lower:]')

# attempt to find the "search «domain»" line. This can get set in a
# variety of ways, including DHCP lease and resolvconf.conf. In essence,
# if the machine knows about a domain name, it is likely to be here.
DNAME=$(grep "^search " /etc/resolv.conf)

# if found, remove the keyword AND its space separator. In other words,
# DON'T edit the following line to remove the space after "search"!
DNAME=${DNAME/#search }

# some systems initialise "search ." (the root domain) so sense that
# and react by treating it as if /etc/resolv.conf didn't have anything
[ "$DNAME" = "." ] && DNAME=

# allow override from the optional argument (if the caller is setting
# a domain explicitly).
DNAME=${2:-$DNAME}

# accept the current domain name as a last resort. On Debian, this
# will probably be set. On Raspberry Pi OS, not so much. But, who knows,
# we might get lucky.
DNAME=${DNAME:-$(hostname -d)}

# sanitise domain name (lower-case letters, digits, hyphens, periods)
# (-dc = delete any characters in the complement of the set)
DNAME=$(echo "$DNAME" | tr -dc '[:alnum:]-.' | tr '[:upper:]' '[:lower:]')

# mimic raspi-config approach to change host name
INIT="$(ps --no-headers -o comm 1)"
if [ "$INIT" = "systemd" ] && systemctl -q is-active dbus && ! ischroot; then
	# note that "set-hostname" appears to be an older command with
	# "hostname" becoming the norm. At the moment, "set-hostname"
	# appears to be backwards compatible on all Debian flavours.
	# and also automatically informs NetworkManager if it is running
	hostnamectl set-hostname "$HNAME"
else
	echo "$HNAME" > /etc/hostname
fi

# could a domain name be determined?
if [ -n "$DNAME" ] ; then

	# yes! apply that
	sed -i  "/127\.0\.1\.1/c 127.0.1.1\t$HNAME.$DNAME\t$HNAME" /etc/hosts

	# report
	echo "Machine name changed to $HNAME.$DNAME"

else

	# no! only a hostname is available
	sed -i  "/127\.0\.1\.1/c 127.0.1.1\t$HNAME" /etc/hosts

	# report
	echo "Machine name changed to $HNAME"

fi

# kick services
echo "Restarting AVAHI and SSH daemons"
service avahi-daemon restart
systemctl restart ssh
