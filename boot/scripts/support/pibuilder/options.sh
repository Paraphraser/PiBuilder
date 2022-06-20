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

# - preference for handling virtual memory swapping. Three options:
#      VM_SWAP=disable
#         turns off swapping. You should consider this on any Pi
#         that boots from SD.
#      VM_SWAP=automatic
#         changes /etc/dphys-swapfile configuration so that swap size
#         is twice real RAM, with a maximum limit of 2GB. In practice,
#         this will usually result in 2GB of swap space. You should
#         consider this if your Pi boots from SSD.
#      VM_SWAP=default
#         the Raspberry Pi OS defaults apply. In practice, this means
#         swap is enabled and the swap space is 100MB.
#   if VM_SWAP is not defined but the old DISABLE_VM_SWAP=true then
#   that combination is interpreted as VM_SWAP=disable
#VM_SWAP=default

# - default language
#   Whatever you change this to must be in your list of active locales
#   (set via ~/PiBuilder/boot/scripts/support/etc/locale.gen.patch)
#LOCALE_LANG="en_GB.UTF-8"

# - Raspberry Pi ribbon-cable camera control
#   Options are: disabled, "false", "true" and "legacy"
#ENABLE_PI_CAMERA=false

#only used if you run the script. These should be kept up-to-date:
#      https://www.sqlite.org/download.html
SQLITEYEAR="2022"
SQLITEVERSION="sqlite-autoconf-3380000"
