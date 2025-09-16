#!/usr/bin/env bash

# must not run as root
[ "$EUID" -eq 0 ] && echo "This script must NOT be run using sudo" && exit 1

# no arguments
[ $# -gt 0 ] && echo "This script does not support any parameters" && exit 1

# the name of this script is
SCRIPT=$(basename "$0")

# the project defaults to
PROJECT_DIR="${PROJECT_DIR:-${HOME}/IOTstack}"

# does the project directory exist?
if [ ! -d "${PROJECT_DIR}" ] ; then

	# no! display workaround
	cat <<-PROJECT

		Error: ${PROJECT_DIR} does not exist. If you have cloned IOTstack to another
		       location, you can invoke this script like this:

		          PROJECT_DIR=path/to/IOTstack ./${SCRIPT}

	PROJECT

	exit 1

fi

# ----------------------------------------------------------------------
# set_dot_env - add, update ~/${PROJECT_DIR}/.env
# ----------------------------------------------------------------------
#
# Arguments:
#    $1 environment key (eg TZ)
#    $2 environment value (eg "Australia/Sydney")
#    $3 update if different (Boolean string, optional, default="false")
# Returns:
#    nothing
# Discussion:
#    1. Checks for presence of key=value, exiting normally if found.
#    2. Checks for presence of key=, appending key=value if not found.
#    3. Updates value if values differ, providing $3="true".
# Note:
#    A copy of this function exists in ./.templates/dot-menu-includes.sh
#
set_dot_env() {
	local DOT_ENV="${PROJECT_DIR}/.env" ; touch "${DOT_ENV}"
	local KEYVAL="${1}=${2}"
	local UPDATE=${3:-false}
	[ $(grep -c "^${KEYVAL}" "${DOT_ENV}") -gt 0 ] && return 0
	if [ $(grep -c -e "^${1}=" "${DOT_ENV}") -eq 0 ] ; then
		echo "${KEYVAL}" >>"${DOT_ENV}"
	elif [ "${UPDATE}" = "true" ] ; then
		sed -i -e "s|^${1}=.*|${KEYVAL}|g" "${DOT_ENV}"
	fi
}

# code below borrowed from xmenu.sh as at 2025-09-16

# ----------------------------------------------------------------------
# set_timezone_for_project
# ----------------------------------------------------------------------
#
# Arguments:
#    none
# Returns:
#    nothing
# Side-effect:
#    copies host timezone to TZ variable in .env
# Note:
#    The mechanism used here should work on both macOS and Linux.
#
set_timezone_for_project() {
	local LOCALTIME=$(realpath "/etc/localtime" 2>/dev/null)
	if [ -n "${LOCALTIME}" ] ; then
		local CITY="$(basename "${LOCALTIME}")"
		local COUNTRY="$(dirname "${LOCALTIME}")"
		COUNTRY="$(basename "${COUNTRY}")"
		set_dot_env "TZ" "${COUNTRY}/${CITY}" true
	else
		set_dot_env "TZ" "Etc/UTC" true
	fi
}

# ----------------------------------------------------------------------
# copy the current machine timezone to the project timezone
# ----------------------------------------------------------------------
set_timezone_for_project
