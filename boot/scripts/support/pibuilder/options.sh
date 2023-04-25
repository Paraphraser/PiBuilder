# this file is "sourced" in all build scripts.

# - country-code for WiFi
#   normally set in Raspberry Pi Imager - will override if made active
#LOCALCC="AU"

# - local time-zone
#   normally set in Raspberry Pi Imager - will override if made active
#LOCALTZ="Etc/UTC"

# - skip full upgrade in the 01 script.
SKIP_FULL_UPGRADE=false

# - skip firmware in the 01 script.
SKIP_EEPROM_UPGRADE=false

# - preference for kernel. Only applies to 32-bit installations. If
#   true, adds "arm_64bit=1" to /boot/config.txt
PREFER_64BIT_KERNEL=false

# - preference for handling virtual memory swapping. Three options:
#      VM_SWAP=disable
#         turns off swapping. You should consider this on any Pi
#         that boots from SD.
#      VM_SWAP=automatic
#         same as "disable" if the Pi is running from SD. Otherwise,
#         changes /etc/dphys-swapfile configuration so that swap size
#         is twice real RAM, with a maximum limit of 2GB. In practice,
#         this will usually result in 2GB of swap space. You should
#         consider this if your Pi boots from SSD.
#      VM_SWAP=custom
#         applies whatever patching instructions are found in:
#            ./support/etc/dphys-swapfile.patch
#         Same as "automatic" but does not check if running from SD.
#      VM_SWAP=default
#         the Raspberry Pi OS defaults apply. In practice, this means
#         swap is enabled and the swap space is 100MB.
#   if VM_SWAP is not defined but the old DISABLE_VM_SWAP=true then
#   that combination is interpreted as VM_SWAP=disable
#VM_SWAP=automatic

# - default language
#   Whatever you change this to must be in your list of active locales
#   (set via ~/PiBuilder/boot/scripts/support/etc/locale.gen.patch)
#LOCALE_LANG="en_GB.UTF-8"

# - Raspberry Pi ribbon-cable camera control
#   Options are: disabled, "false", "true" and "legacy"
#ENABLE_PI_CAMERA=false

# - Handling options for .bashrc and .profile
#   Options are: "append" (default), "replace" and "skip"
#   See PiBuilder "login" tutorial
#DOT_BASHRC_ACTION=append
#DOT_PROFILE_ACTION=append
