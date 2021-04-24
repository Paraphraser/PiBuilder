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

# omit if you don't have a GPG Key ID
GPGKEYID=04B9CD3D381B574D

# clone IOTstackAliases repo if not present already
IOTSTACK_ALIASES="$HOME/.local/IOTstackAliases/dot_iotstack_aliases"
# source the aliases - if installed
if [ -e "$IOTSTACK_ALIASES" ] ; then
    . "$IOTSTACK_ALIASES"
fi
unset IOTSTACK_ALIASES