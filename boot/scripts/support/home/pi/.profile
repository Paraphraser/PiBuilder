# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
	. "$HOME/.bashrc"
    fi
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

# the above is the DEFAULT ~/.profile - you should replace this entire
# file with your customised .profile. You should keep this file in sync
# with your customised .profile
#
# the lines below are optional

# clone IOTstackAliases repo if not present already
IOTSTACK_ALIASES="$HOME/.local/IOTstackAliases/dot_iotstack_aliases"
# source the aliases - if installed
if [ -e "$IOTSTACK_ALIASES" ] ; then
    . "$IOTSTACK_ALIASES"
fi
unset IOTSTACK_ALIASES

# https://www.docker.com/blog/faster-builds-in-compose-thanks-to-buildkit-support/
# https://docs.docker.com/compose/reference/build/#native-build-using-the-docker-cli
# https://docs.docker.com/compose/reference/envvars/#compose_docker_cli_build
export COMPOSE_DOCKER_CLI_BUILD=1
export DOCKER_BUILDKIT=1
echo "Note: COMPOSE_DOCKER_CLI_BUILD=$COMPOSE_DOCKER_CLI_BUILD, DOCKER_BUILDKIT=$DOCKER_BUILDKIT"

