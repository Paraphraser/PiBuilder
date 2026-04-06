#!/usr/bin/env bash

#
# In https://github.com/SensorsIot/IOTstack/pull/740, Slyke recommended
# using git clone --filter=tree:0 when cloning IOTstack. I hit some
# consequences of using "treeless clones" when developing iotstack_menu,
# which were (a) EXTREMELY long delays while Git sorted itself out, and
# (b) an occasional outright refusal of Git to permit adding a second
# remote and pulling a branch from that remote.
#
# The purpose of this script is to try to convert a "treeless" clone
# into more or less what you would get if you had omitted the --filter
# in the first place.
#
# This script assumes a starting position like this:
#
#    git clone --filter=tree:0 https://github.com/SensorsIot/IOTstack.git IOTstack
#
# That defaults to a remote named "origin". It also adds a local
# config option remote.${REMOTE}.partialclonefilter=tree:0.
#
# This script assumes it is run in the local working directory, as in:
#
#    cd ~/IOTstack
#    ~/PiBuilder/boot/scripts/upgrade_treeless_clone.sh
#
# The script makes the following checks:
#
# 1. That it is not being run via sudo.
# 2. That the working directory is a git repository.
# 3. That a remote named "origin" exists. It is possible to pass an
#    alternative remote using an environment variable. Example:
#
#       REMOTE=upstream ~/PiBuilder/boot/scripts/upgrade_treeless_clone.sh
#
# 4. That the relevant configuration option exists and has the expected
#    value. In most cases that will be remote.origin.partialclonefilter=tree:0
#
# If all checks pass then the script tells Git to fetch the missing
# bits and pieces, finishing off by removing the configuration option
# which was the signature of a treeless clone.
#
# This script is not IOTstack-specific. It should work for any repo
# which has been cloned with --filter=tree:0. Worst case should be
# the need to prepend REMOTE= to the call. There are, however, no
# guarantees so "use at your own risk".

# support user renaming of script
SCRIPT=$(basename "$0")

# should not run as root
[ "$EUID" -eq 0 ] && echo "This script should NOT be run using sudo" && exit 1

# sense that the working directory is not a git repository
if ! git rev-parse >/dev/null 2>&1 ; then
	echo "Git says the working directory is not a git repository"
	exit 1
fi

# the default remote is
REMOTE=${REMOTE:-origin}

# the option keyword and expected value are
OPTION_KEY="remote.${REMOTE}.partialclonefilter"
OPTION_EXPECTED="tree:0"

# sense unknown remote
if ! git remote get-url "${REMOTE}" >/dev/null 2>&1 ; then
	echo "Git says there is no remote named '${REMOTE}'"
	exit 1
fi

# attempt to fetch the relevant configuration option
OPTION=$(git config --local "${OPTION_KEY}")

# sense option does not have unexpected value
if [ "${OPTION}" != "${OPTION_EXPECTED}" ] ; then
	cat <<-NOOPTION
		Git says no local option «${OPTION_KEY}=${OPTION_EXPECTED}» exists.
		The absence of that option suggests this repository may not be a treeless clone.
	NOOPTION
	exit 1
fi

echo "This repository passes the tests for a treeless clone."
echo "Attempting to convert."

# attempt to re-fetch everything, without a tree:0 filter
echo "Step 1: re-fetching from ${REMOTE} without --filter=${OPTION_EXPECTED}"
git fetch --refetch --no-filter

echo "Steo 2: removing ${OPTION_KEY} from local configuration"
git config unset --local "${OPTION_KEY}"

echo "Completed."
