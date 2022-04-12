# this file is "sourced" in all build scripts.

# - country-code for WiFi
#   normally set in Raspberry Pi Imager - will override if made active
#LOCALCC="AU"

# - local time-zone
#   normally set in Raspberry Pi Imager - will override if made active
#LOCALTZ="Etc/UTC"

# - skip full upgrade in the 01 script.
SKIP_FULL_UPGRADE=false

# - preference for kernel. Only applies to 32-bit installations. If
#   true, adds "arm_64bit=1" to /boot/config.txt
PREFER_64BIT_KERNEL=false

# - preference for disabling swap. You should consider this on any Pi
#   that boots from SD.
DISABLE_VM_SWAP=false

# - default language
#   Whatever you change this to must be in your list of active locales
#   (set via ~/PiBuilder/boot/scripts/support/etc/locale.gen.patch)
#LOCALE_LANG="en_GB.UTF-8"

# - Raspberry Pi ribbon-cable camera control
#   Options are: disabled, "false", "true" and "legacy"
#ENABLE_PI_CAMERA=false

# - override for docker-compose version number. See:
#     https://github.com/docker/compose/releases
#DOCKER_COMPOSE_VERSION="v2.4.1"
# - override for docker-compose architecture. Options are:
#     armv7
#     aarch64
#   armv7 will work on both 32-bit and 64-bit kernels (this is the
#   default) while aarch64 will only work on a 64-bit kernel.
#DOCKER_COMPOSE_ARCHITECTURE="armv7"

#only used if you run the script. These should be kept up-to-date:
#      https://www.sqlite.org/download.html
SQLITEYEAR="2022"
SQLITEVERSION="sqlite-autoconf-3380000"
