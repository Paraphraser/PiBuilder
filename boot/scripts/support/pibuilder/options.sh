# this file is "sourced" in all build scripts.

# - country-code for WiFi
LOCALCC="AU"

# - local time-zone
LOCALTZ="Etc/UTC"

# - default language
#   Whatever you change this to must be in your list of active locales
#   (set via ~/PiBuilder/boot/scripts/support/etc/locale.gen.patch)
LOCALE_LANG="en_GB.UTF-8"

# - override for docker-compose version number. See:
#     https://github.com/docker/compose/releases
#DOCKER_COMPOSE_VERSION="v2.1.1"
# - override for docker-compose architecture. Options are:
#     armv7
#     aarch64
#   armv7 will work on both 32-bit and 64-bit kernels (this is the
#   default) while aarch64 will only work on a 64-bit kernel.
#DOCKER_COMPOSE_ARCHITECTURE="armv7"

# set true to install Home Assistant supervised
HOME_ASSISTANT_SUPERVISED_INSTALL=false
# - override for Home Assistant agent version number. See:
#      https://github.com/home-assistant/os-agent/releases/latest
#HOME_ASSISTANT_AGENT_RELEASE="1.2.2"

#only used if you run the script. These should be kept up-to-date:
#      https://www.sqlite.org/download.html
SQLITEYEAR="2021"
SQLITEVERSION="sqlite-autoconf-3360000"
