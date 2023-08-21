# PiBuilder Change Summary

* 2023-08-21

	- Adds support for GRUB-based boots. Default patch disables IPv6.
	- Improved handling of python3-ykman (not available on Buster).
	- Bump SQLite version to 3420000.

* 2023-08-13

	- Bump default version of docker-compose installed via script to v2.20.3

* 2023-08-08

	- Tested PiBuilder on Ubuntu Bookworm guest under Proxmox.
	- Included mention of Debian Bookworm guest under Proxmox, tested previously.
	
* 2023-08-07

	- Skip locales generation following a patch failure. Ubuntu already has many more locales enable by default than either Raspberry Pi OS or Debian so, if the desired locale is not among them, it's better to have users prepare custom patches that are actually relevant to their specific situations, rather than plough on and regenerate redundant locales (a lot of wasted build time for no gain).

* 2023-08-02

	- After cloning the IOTstack repo in 03 script, create the `.new_install` marker file. This bypasses the somewhat misleading dialog about the repo not being up-to-date (after a clean clone it will, by definition, be in-sync with GitHub).
	- Simulate effect of [PR723](https://github.com/SensorsIot/IOTstack/pull/723) when Bookworm is the running OS. This removes version pins from `requirements-menu.txt`, which is needed for a successful install on Bookworm. 

* 2023-07-31

	- Define meaning and usage of «guillemets» as placeholders.
	- Expand example of calling 01 script with and without «hostname» argument.
	- Sanitise «hostname» argument (lower-case letters, digits and hyphens)
	- Mimic `raspi-config` method of changing hostname so it also works on non-Raspberry Pi (eg Debian, Proxmox VE).
	- Simpler `cp -n` syntax for copying `resolvconf.conf`.

* 2023-07-30

	- Expand [Configuring Static IP addresses on Raspbian](./docs/ip.md) to clarify use of `domain_name_servers` field in `dhcpcd.conf`. This follows on from a misunderstanding revealed in a discussion on [Discord](https://discord.com/channels/638610460567928832/638610461109256194/1134819901626925159).
	- Adds how-to for setting up a Pi as an authoritative DNS server.

* 2023-07-19

	- Bump default version of docker-compose installed via script to v2.20.1
	- And later the same day to v2.20.2

* 2023-07-17

	- Major documentation restructure:

		- Rather than cloning PiBuilder onto your support host, then copying the contents of `~/PiBuilder/boot` to the `/boot` partition such that scripts are run like this:

			```
			$ /boot/scripts/01_setup.sh «new host name»
			$ /boot/scripts/02_setup.sh
			…
			```

			the focus is on cloning PiBuilder onto the Raspberry Pi and running the scripts like this:
		
			```
			$ ~/PiBuilder/boot/scripts/01_setup.sh «new host name»
			$ ~/PiBuilder/boot/scripts/02_setup.sh
			…
			```

			The older mechanism still works but the newer mechanism is more straightforward when trying to use PiBuilder in situations where the `/boot` partition does not exist (eg Proxmox, Parallels, non-Pi hardware).
			
			The new approach can also be used with customised builds. Instead of cloning PiBuilder onto your Pi from GitHub, you:
			
			1. Clone PiBuilder onto your support host from GitHub.
			2. Customise PiBuilder on your support host.
			3. Clone the customised instance onto your Pi from your support host.

		- Main README simplified and aimed at first-time users.
		- Customisation documentation moved to "advanced" README.
		- Acknowledgement: Andreas suggested this change of approach.

	- Explain how to enable SAMBA sharing of home directory.
	- Rewrite VNC documentation and explain how to install TightVNC as an alternative to RealVNC.

* 2023-07-12

	- Bump default version of docker-compose installed via script to v2.20.0
			
* 2023-07-03

	- First pass at supporting Debian Bookworm. A test build can start with:

		1. Go to the [Raspberry Pi OS downloads](https://www.raspberrypi.com/software/operating-systems/) page.
		2. Find the "Raspberry Pi OS (64-bit)" grouping (half way down the page).
		3. Download "Raspberry Pi OS with desktop" May 3rd 2023.

		The expected filename is `2023-05-03-raspios-bullseye-arm64.img.xz`
		
	- To build based on Bookworm:

		```
		$ DEBIAN_BOOKWORM_UPGRADE=true /boot/scripts/01_setup.sh {«hostname»}
		```
		
* 2023-07-01

	- Bump default version of docker-compose installed via script to v2.19.1

* 2023-06-22

	- Bump default version of docker-compose installed via script to v2.19.0

* 2023-05-18

	- Bump default version of docker-compose installed via script to v2.18.1

* 2023-05-17

	- Bump default version of docker-compose installed via script to v2.18.0

* 2023-05-15

	- Fix bug in tidyPATH() function.

* 2023-04-27

	- Support third (optional, boolean) argument to `try_patch()`. If true, the function will return success even if the patching operation fails.
	- Better support for `LOCALE_LANG` on non-Pi hosts. If the language defined by `LOCALE_LANG` is active in `/etc/locale.gen` (either because that's the default or because a patch was successful in making it active) then that language will be made the default. Otherwise the setting will be skipped with a warning.
	- All language setting now occurs in 02 script.
	- Add SSHD and SSH restarts to 01 script to try to improve end-of-script reboot reliability. 

* 2023-04-25

	- Rename SQLite installation script from `06_setup.sh` to `install_sqlite.sh` in the `helpers` subdirectory.
	- Support for `LOCALCC` and `LOCALTZ` withdrawn in favour of setting via Raspberry Pi Imager.

* 2023-04-21

	- Bump default version of docker-compose installed via script to v2.17.3

* 2023-04-17

	- Bump default version of SQLite to 3410200

* 2023-03-27

	- Bump default version of docker-compose installed via script to v2.17.2

* 2023-03-25

	- Bump default version of docker-compose installed via script to v2.17.1

* 2023-03-24

	- Bump default version of docker-compose installed via script to v2.17.0

* 2023-02-09

	- Bump default version of docker-compose installed via script to v2.16.0
	- Bump SQLite to version 3400100
	- Adds `VMSWAP=custom` to support custom VM configurations

* 2023-01-10

	- Bump default version of docker-compose installed via script to v2.15.1 (for S474N)

* 2023-01-07

	- Bump default version of docker-compose installed via script to v2.15.0 (for S474N)

* 2023-01-04

	- add capability for installing `/etc/docker/daemon.json`
	- Bump default version of docker-compose installed via script to v2.14.2 

* 2022-11-27

	- Change log split to dedicated file.
	- Bump default version of docker-compose installed via script to v2.13.0

* 2022-11-23

	- First cut at supporting platforms other than Raspberry Pi and/or Raspberry Pi OS.
	- Default version of SQLite bumped to 3400000.

* 2022-11-03

	- Adds check for firmware upgrade to 01 Script plus `SKIP_EEPROM_UPGRADE` option to bypass the upgrade. See [All3DP tutorial](https://all3dp.com/2/raspberry-pi-4-firmware-update-tutorial/) for background.
	- Changes definition of `SKIP_FULL_UPGRADE` as follows:

		- if `false`, performs `sudo apt full-upgrade -y`;
		- if a value other than `false`, performs `sudo apt upgrade -y`
		- unconditionally performs `sudo apt autoremove -y`

	- Bump default version of docker-compose installed via script to v2.12.2.

* 2022-10-11

	- Bump default version of docker-compose installed via script to v2.11.2.
	- Support `/etc/sysctl.d` merging in addition to `/etc/sysctl.conf` patching. Previous default patch to disable IPv6 is now applied via `/etc/sysctl.d/local.conf`.

* 2022-09-22

	- Bump default version of docker-compose installed via script to v2.11.1.
	- Add comments to header of `install_docker-compose-plugin.sh` so its purpose is clear.
	- Add `reset_menu_enviroment.sh` script and associated documentation to try to reset Python environment so menu will run post [PR560](https://github.com/SensorsIot/IOTstack/pull/560).
	- Related changes to 04 script.

* 2022-09-16

	- Adds `try_merge()` function and employs it 02 script to conditionally merge the `/etc/network` folder. This can be used to customise network interfaces such as setting up VLANs.
	- Adds `python3-virtualenv` and `software-properties-common` to the list of packages installed by 03 script. The former is now an IOTstack dependency. The latter is in anticipation of Python 3.10.
 
* 2022-08-30

	- When IPv6 is disabled, `exim4` writes messages to its panic log every day which also turn up in the system log. This change stops that from happening.

* 2022-08-25

	- Bump default version of docker-compose installed via script to v2.10.1
	- Rename `upgrade_docker-compose.sh` to `install_docker-compose.sh` to reflect the fact that the script depends on `uninstall_docker-compose.sh` having been run beforehand.

* 2022-08-23

	- Improvements to `~/.bashrc` and `~/.profile` handling:

		- Add [tutorial](./docs/login.md).
		- Add reference versions of login documents.
		- Support `DOT_PROFILE_ACTION` and `DOT_BASHRC_ACTION` options with values `append` and `replace`.

	- Bump docker-compose to v2.10.0.
	- Bump SQLite to version 3390200.
	- Remove `COMPOSE_DOCKER_CLI_BUILD=1` (now implied by `DOCKER_BUILDKIT=1`). Also remove obsolete cross-reference URLs in favour of up-to-date URL. 

* 2022-08-15

	- Add sub-headings to make it clear which commands are being executed on the support host vs those being executed on the Raspberry Pi.
	- Expand section on copying required files to boot volume to try to cater for Linux, macOS, Windows, and whether the tool of choice is the command line or a GUI.

* 2022-07-27

   - Implement suggestion from Andreas Spiess to:

	   - change the implementation of `VM_SWAP=automatic` (02 script) to sense whether the Pi is running from SD and, if so, disable VM swapping (ie a synonym for `VM_SWAP=disable`).
	   - make `VM_SWAP=automatic` the default.

	   Together, "automatic" should then handle the majority of situations correctly.
	   
	- Move SAMBA discussion to [tutorial document](./docs/samba.md).
	- Remove cautionary words about full 64-bit Bullseye. The wording was never *intended* to direct users to the 32-bit system but it seemed to be having that effect.
	- Adds a note to the 01 script detail explaining the change of boot mode (which is noticeable if the Pi is connected to an HDMI screen).

* 2022-07-05

	- In 01 script, optional prolog should not run until *after* the baseline snapshots are taken.

* 2022-07-04

	- Explains how to set up credentials files on boot partition and provides helper scripts to assist with the process. This an alternative to using Raspberry Pi Imager.

* 2022-06-29

	- Deprecates `~/.profile` support in `05_setup.sh` in favour of `~/.bashrc`:

		- The previous arrangement always **replaced** `~/.profile`.
		- The new arrangement **appends** to `~/.bashrc`.

		Switching to `~/.bashrc` solves a problem when the Desktop (VNC or console) is enabled **and** `~/.profile`, or any file sourced by `~/.profile`, contains syntactic constructs unique to `bash`.

		VNC and console logins:

		- occur under `sh` so any `bash` constructs will fail and prevent login.
		- only invoke `~/.profile` so it is the only script that needs to be compatible with `sh`.

		PiBuilder now assumes the presence of the default version of `~/.profile` that ships with Raspberry Pi OS and no longer interferes with that file.

* 2022-06-20

	- The "convenience script" (`https://get.docker.com | sudo sh`) for installing `docker` also installs `docker-compose-plugin`. That, in turn, means that = both `docker` and `docker-compose-plugin` are maintained by regular `apt update ; apt upgrade`.
	- The `04_setup.sh` script now takes advantage of this arrangement and creates a symlink in `/usr/local/bin` so that both the *command* (`docker-compose`) and *plugin* (`docker compose`) forms work from a single binary.
	- [Maintaining docker + docker-compose](./docs/reinstallation.md) updated to explain the above.
	- `upgrade_docker-compose.sh` reduced to help text pointing to revised documentation.
 	- `uninstall_docker-compose.sh` adjusted to also remove the `docker-compose-plugin` package.
	- `DOCKER_COMPOSE_VERSION` and `DOCKER_COMPOSE_ARCHITECTURE` removed from `options.sh`.

* 2022-06-05

	- Bump docker-compose to v2.6.0

* 2022-05-19

	- Bump docker-compose to v2.5.1

* 2022-05-11

	- Deprecate `niet` YAML CLI parsing tool in favour of `shyaml`. Avoids installation warnings.

* 2022-05-09

	- Deprecate `DISABLE_VM_SWAP` in favour of `VM_SWAP` with the choices:

		-  `disable` is the same as `DISABLE_VM_SWAP=true`
		-  `default` is the same as `DISABLE_VM_SWAP=false`
		-  `automatic` will generally result in a 2GB swap file (up from the 100MB default). 

* 2022-05-06

	- All docker, docker-compose maintenance activities (remove, re-install, upgrade) moved to [Maintaining docker + docker-compose](./docs/reinstallation.md).

* 2022-05-02

	- Bump docker-compose to v2.5.0
	- Switch from `curl` to `wget` for docker-compose downloads (slightly better error-handling)

* 2022-04-13

	- consolidate dependencies on `/boot/scripts/support/home/pi` into the 05 script.
	- 05 script now checks for `/boot/scripts/support/home/$USER`. If that path does not exist, the script substitutes `/boot/scripts/support/home/pi`. This will avoid the need to duplicate the "pi" home folder structure for each distinct «username».
	- 03 script now does protective creation of `$HOME/IOTstack/backups` and `$HOME/IOTstack/services`. This prevents `docker-compose` from creating those folders with root ownership. Follows-on from a question on Discord.
	- Moves `mkdocs` setup to 03 script.

* 2022-04-12

	- Adapt to [2022-04-04 changes](https://downloads.raspberrypi.org/raspios_arm64/release_notes.txt) made by Raspberry Pi Foundation (no "pi" user, no default password, etc).
	- Null `ssh` file removed from boot folder (now set in Raspberry Pi Imager). Creating `/boot/ssh` still works and has the expected effect of enabling SSH.
	- `wpa_supplicant.conf` template removed from boot folder (now set in Raspberry Pi Imager). Adding `/boot/wpa_supplicant.conf` still works and has the expected effect of enabling WiFi but Raspberry Pi Imager goes to the trouble of masking the WiFi PSK so it's a better choice. 
	- PiBuilder options changed - `LOCALCC` and `LOCALTZ` default to commented-out. These values should be set in Raspberry Pi Imager. Enabling `LOCALCC` and/or `LOCALTZ` still works and still has the expected effect.
	- VNC changes:

		- password support moved out of 01 Script to `set_vnc_password.sh` helper script.
		- `common.custom` template removed from support structure (embedded in `set_vnc_password.sh`)
		- vnc.md tutorial updated to explain use of `set_vnc_password.sh` script.

	- other 01 script changes:

		- hostname parameter now optional. If invoked as:

			```
			/boot/scripts/01_setup.sh
			```

			then HOSTNAME will not change. If invoked as:

			```
			/boot/scripts/01_setup.sh newhostname
			```

			then HOSTNAME will change if and only if newhostname is different.

		- user password change no longer enforced (assumes a strong password set in Raspberry Pi Imager).

	- `/boot/scripts/support` is no longer assumed. Path to `support` directory is now discovered dynamically, relative to `0x_setup.sh` script.

* 2022-04-09

	- Fix `/home/pi` assumption in crontab template. Also expands template to provide a lot more inline help text. 

* 2022-04-06

	- Withdraw all support for Supervised Home Assistant. See [About Supervised Home Assistant](./docs/home-assistant.md) for more information.

* 2022-04-05

	- Workaround for [PiBuilder issue 4](https://github.com/Paraphraser/PiBuilder/issues/4) / [HA issue 207](https://github.com/home-assistant/supervised-installer/issues/207). Manifests in 04 script as:

		```
		cp: cannot stat '/etc/default/grub': No such file or directory
		```

		Related info:
		 
		* [HA issue 3444](https://github.com/home-assistant/supervisor/issues/3444)
		* [HA PR 201](https://github.com/home-assistant/supervised-installer/pull/201)
		* [HA PR 206](https://github.com/home-assistant/supervised-installer/pull/206)

	- Bump docker-compose to v2.4.1

* 2022-03-15

	- Add instructions for enabling VNC

* 2022-03-10

	- Bump docker-compose to v2.3.3 (this version supports `device_cgroup_rules` - see [PR9251](https://github.com/docker/compose/pull/9251))
	- Rename `SKIP_FULL_UPDATE` to `SKIP_FULL_UPGRADE`.
	- Document `SKIP_FULL_UPGRADE`.
	- Add `ENABLE_PI_CAMERA` documentation.
	- Remove recommendation to stick with Buster for camera support.
	- Update SQLite version numbers.

* 2022-02-10

	- Add scripts for uninstalling then reinstalling docker, docker-compose and supervised home assistant.
	- Add documentation explaining the new scripts.
	- Rename scripts with `docker_compose` in the name to use `docker-compose`.

* 2022-02-09

	- Adjust for revised layout of [Raspberry Pi OS](https://www.raspberrypi.com/software/operating-systems/) releases page.

* 2022-01-27

	- Fix bugs in `upgrade_docker-compose.sh` script
	- Add `find_docker-compose.sh` helper script

* 2022-01-17

	- Default `.gitconfig` options updated to include effects of running these commands:

		```bash
		$ git config --global fetch.prune true
		$ git config --global pull.rebase true
		$ git config --global diff.colorMoved zebra
		$ git config --global rerere.enabled true
		$ git config --global alias.lg "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
		```

	- Version of docker-compose PiBuilder installs by default bumped to v2.2.3.
	- Script to upgrade docker-compose added to helpers folder.

* 2022-01-09

	- patch `journald.conf` to control excessive log messages in the following pattern ([stackoverflow](https://stackoverflow.com/questions/63622619/docker-flooding-syslog-with-run-docker-runtime-logs)):

		```
		run-docker-runtime\x2drunc-moby-«identifier»-runc.3doejt.mount: Succeeded.
		```

* 2022-01-08

	- add SAMBA support to 03 script.

* 2022-01-02

	- 04 script appends following to `/boot/cmdline.txt`:

		* `cgroup_memory=1 cgroup_enable=memory` (unconditional)
		* `apparmor=1 security=apparmor` if Supervised Home Assistant is installed

* 2021-12-31

	- Setting of VNC password conditional on presence of parent directory (for "lite" base image).

* 2021-12-30

	- Explain how to disable WiFi

* 2021-12-29

	- Improve documentation on OS versions tested with PiBuilder and how to choose between them.
	- Add instructions for checking SHA256 signatures.
	- Split `options.sh` instructions into "should" and "can" categories.
	- Document `cmdline.txt` and `config.txt` script changes made yesterday.
	- Add support for disabling VM swapping.
	- Rewrite some sections of DNS tutorial.
	- Fix typos etc.
	- Change-summary to the end of the readme.

* 2021-12-28

	- Rename `is_running_raspbian()` function to `is_running_OS_release()`. The full 64-bit OS identifies as "Debian". That part of the test removed as unnecessary.
	- Add `is_running_OS_64bit()` function to return true if a full 64-bit OS is running.
	- Install 64-bit docker-compose where appropriate.
	- Install 64-bit Supervised Home Assistant where appropriate.
	- Automatically enable `docker stats` (changes `/boot/cmdline.txt`).
	- Update default version numbers in `options.sh`.
	- Add `PREFER_64BIT_KERNEL` option, defaults to false.

* 2021-12-14

	- 04 script now fully automated - does not pause during Home Assistant installation to ask for architecture.
	- re-enable locale patching - now split across 01 and 02 scripts.

* 2021-12-03

	- disable locales patching - locales_2.31-13 is incompatible with previous approach.
	- better default handling of `isc-dhcp-fix.sh` - `/etc/rc.local` now only includes interfaces that are defined, active, and obtained their IP addresses via DHCP.
	- added support for Raspberry Pi Zero W2 + Supervised Home Assistant. 

* 2021-11-25

	- major overhaul
	- tested for Raspbian Buster and Bullseye
	- can install Supervised Home Assistant
	- documentation rewritten
