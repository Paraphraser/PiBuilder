# PiBuilder Change Summary

* 2024-12-27

	- Minor edits to Proxmox documentation to update examples to a more-recent Debian image, and to clarify that the login screen depends on Desktop vs Console choices.
	- Expand on HA installation.

* 2024-12-19

	- Bump default version of docker-compose installed via script to v2.32.1.

* 2024-12-14

	- Bump default version of docker-compose installed via script to v2.32.0. `apt` currently installs v2.31.0.

* 2024-11-16

	- Add `iputils` commands to 03 script (mainly `arping` and `tracepath`).

	- Bump default version of docker-compose installed via script to v2.30.3.

* 2024-11-06

	- Bump default version of docker-compose installed via script to v2.30.2.

* 2024-11-03

	- Bump default version of docker-compose installed via script to v2.30.1 (skips v2.30.0).

* 2024-09-30

	- Use correct port 8006 (not 8086) for connecting to Proxmox-VE GUI. Thanks to `@trebornerg` on Discord for spotting and reporting this. 

* 2024-09-20

	- Bump default version of docker-compose installed via script to v2.29.6.

	- And then again (same day) to v2.29.7.

		Meanwhile, v2.29.6 has made it into the `apt` repositories so it doesn't include [PR12141](https://github.com/docker/compose/pull/12141) added in v2.29.7:
		
		```
		revert commits link to mount API over bind changes
		``` 

* 2024-09-18

	- Bump default version of docker-compose installed via script to v2.29.5 (2.29.3 and 2.29.4 seemed less stable).

* 2024-08-23

	- Bump default version of docker-compose installed via script to v2.29.2.
	- Add instructions to [VNC](./docs/vnc.md) for adding Chromium browser.

* 2024-08-12

	- A change to the default version of `/etc/dphys-swapfile` supplied with recent versions of Raspberry Pi OS Bookworm created a conflict the relevant patching instructions. A new `try_edit()` function has been implemented via which a file of editing commands can be passed to `sed`. That is now being used to edit `/etc/dphys-swapfile` such that swap space is calculated as twice physical RAM, capped to 2GB. This is actually the default for `dphys-swapfile`. The edit merely undoes the Raspberry Pi Foundations changes.

	- If PiBuilder senses the presence of an `/etc/dphys-swapfile.patch`, it displays a deprecation warning and forces `VM_SWAP=default` which amounts to just leaving things alone. This only affects Raspberry Pis running Raspberry Pi OS.

* 2024-08-06

	- Alter how Python "break system packages" functionality is implemented. Previously, all scripts tested for the presence of Bookworm and, from that, *inferred* that `--break-system-packages` should be passed to `pip3`. This was an interim strategy which was going to break on Debian "trixie" and was guaranteed to fail on Ubuntu which uses different names. With this change, all calls to `pip3` are implemented like this:

		```
		$ PIP_BREAK_SYSTEM_PACKAGES=1 pip3 uninstall -y docker-compose
		```
		
		This should be platform, distribution and release agnostic. If Python on the platform cares about "break system packages" then it will respect the environment variable; otherwise the variable will be ignored.

	- Adds `apt-util` to basic packages in 01 script (missing on Ubuntu server).

	- Check for existence of `/etc/locale.gen` before attempting merge, plus improved warning text from `edit_locales.sh` helper script.

* 2024-07-25

	- Bump default version of docker-compose installed via script to v2.29.1. This is also the version you get with a routine `apt upgrade`.

* 2024-06-26

	- Bump default version of docker-compose installed via script to v2.28.1.

* 2024-06-21

	- Bump default version of docker-compose installed via script to v2.28.0. In the past few days, v2.27.2 and v2.27.3 have been released in rapid succession. PiBuilder is skipping straight to v2.28.0.

* 2024-06-12

	- Explain how to re-enable Network Manager in a no-Desktop environment.
	- Add instructions for undoing automatic boot-to-console set by 01 script.

* 2024-06-07

	- try_patch() function changed so that it will not attempt to patch non-existent targets. Documentation updated accordingly.
	- try_patch() function messages made more succinct.
	- patch of `/etc/dhcpcd.conf` not attempted in the presence of Network Manager.
	- add documentation to explain how to set static IP addresses in the presence of Network Manager.

* 2024-05-29

	- Bump default version of docker-compose installed via script to v2.27.1.
	- Add `is_NetworkManager_running()` function (defined as `systemctl` stating "active" and `nmcli` being in the search path and `nmcli` stating "running".
	- Add `edit_locales.sh` helper script to try to workaround the continual problems caused by locales being a bit of a moving target.
	- 01 script sets boot behaviour to console for pure Debian, (mirroring Raspberry Pi).
	- 02 script:

		- adopts `is_NetworkManager_running()` function.
		- adopts better practice of setting interface to `ignore` (rather than `disable`) when inactivating IPv6.
		- provides support for running a `/etc/NetworkManager/custom_settings.sh` which, if present, should contain `nmcli` scripts (eg for setting static IP addresses).
		- adopts the `edit_locales.sh` helper script for editing locales. The old patch mechanism is now deprecated.

* 2024-04-25

	- Bump default version of docker-compose installed via script to v2.27.0.
	- Add optional step to adjust console font size for Debian guests.

* 2024-04-24

	- Explains how to create Proxmox-VE Debian guest *without* enabling a Desktop. A console-only guest does not activate mDNS so this needs to be installed and enabled before the guest will respond to its name in the `.local` domain.

* 2024-04-12

	- An unexpected side-effect of [2024-04-09](#20240409) is journal warnings from NetworkManager as it repeatedly tries to enable IPv6 on the physical interfaces (eg `eth0` and `wlan0`). The underlying cause is NetworkManager defaulting to `ipv6.method=auto` for physical interfaces.

		The 02 script now sets `ipv6.method=disabled` on the physical interfaces. This prevents the retries and silences the warnings. The strategy will only catch the physical interfaces that exist when the script is run. It will be up to the user to notice and react to any journal warnings coming from physical interfaces that are defined later (eg USB-to-Ethernet dongles). For example, if a second wired interface were to be added, the user would need to:

		``` console
		$ sudo nmcli conn mod "Wired connection 2" ipv6.method "disabled"
		$ sudo systemctl restart NetworkManager
		```

		The `lo` and virtual interfaces created by Docker all default to IPv6 being disabled. This is because they take their lead from the options set by `sysctl` (which are applied via the NetworkManager hook script per [2024-04-09](#20240409)).

	- Make `isc-dhcp-fix.sh` conditional on:

		1. NetworkManager not active.
		2. `/etc/rc.local` world-executable with non-zero length (Debian and Ubuntu typically create `rc.local` as empty and without execute permission).
		3. `isc-dhcp-fix.sh` (or a host-specific version) must exist.

	- Reinstate support for merging `/etc/default/grub.d`. Originally, this was used to add the file `no-ipv6.cfg` with the line:

		```
		GRUB_CMDLINE_LINUX="ipv6.disable=1"
		```

		but that mechanism has been superseded. Nevertheless, the ability to patch grub can be useful.

	- Add `python3-braceexpand` to package list in 03 script. This is being recommended when rsync is installed.

* 2024-04-10

	- Baseline copying and editing of `cmdline.txt` and `config.txt` not working properly on Bookworm because of relocation of those files from `/boot` to `/boot/firmware` (a mount point). Adds `path_to_pi_boot_file()` function which searches `firmware` first then falls back to `boot`. Scripts 01 and 04 updated accordingly.

* <a name="20240409"></a>2024-04-09

	- Improve method for disabling IPv6. Originally, disabling IPv6 was accomplished by setting appropriate options in `/etc/sysctl.d/local.conf`.

		That worked on the Pi in Buster and Bullseye but not in Bookworm.

		The mechanism also never worked on any Debian install (irrespective of release) if Network Manager was present. The solution there was to configure grub to turn off IPv6 at boot time. That solution is deprecated by this change.

		The Raspberry Pi doesn't use grub so the scheme didn't work for Bookworm.

		It *appears* that there is some underlying conflict with Network Manager. My analysis suggests `sysctl` options are being applied early in the boot process, but then Network Manager undoes those changes.

		Googling has led to [this post](https://bbs.archlinux.org/viewtopic.php?id=282819). The solution works by adding a hook script which causes Network Manager to re-apply the `sysctl` settings after every Network Manager change.

		This scheme has the advantage that it works on both Bullseye and Bookworm, in a platform-independent manner, and irrespective of whether Network Manager is active.

		It isn't clear whether the duel between NetworkManager and `sysctl` is a feature (ie Network Manager is *intended* to override `sysctl`) or a bug (ie the two *should* co-exist). The available documentation is remarkably silent on this question, and the web as a whole is remarkably silent on the existence of this problem.

* 2024-03-30

	- Bump default version of docker-compose installed via script to v2.26.1.

* 2024-03-24

	- Bump default version of docker-compose installed via script to v2.26.0 (`apt upgrade` is up to v2.25.0).
	- Better Unicode range for boxed letters in Running on Proxmox-debian.

* 2024-03-17

	- Bump default version of docker-compose installed via script to v2.25.0.
	- Rewrite Raspberry Pi Imager section of main README to account for GUI changes.
	- Update screen capture of releases page for 2024-03-12 and explain pros and cons of Desktop vs Lite image variants.

* 2024-03-08

	- Bump default version of docker-compose installed via script to v2.24.7.

* 2024-02-19

	- Bump default version of docker-compose installed via script to v2.24.6.

* 2024-02-04

	- Bump default version of docker-compose installed via script to v2.24.5. This was released 31/Jan to fix a Windows problem so I decided to skip it as not relevant to PiBuilder builds. However, v2.24.5 is now the default with `apt upgrade` so PiBuilder may as well follow suit.

* 2024-01-30

	- Bump default version of docker-compose installed via script to v2.24.4 (v2.24.3 skipped because it was only relevant to Docker Desktop for Windows).

* 2024-01-24

	- Bump default version of docker-compose installed via script to v2.24.2. Note that the version currently installed/upgraded by `apt` is v2.24.1.

* 2024-01-15

	- Remove `-4` flag from SSH command prior to 01 script. Using this stalls Ubuntu on Proxmox-VE which, for some reason, changes its IPv4 address during the `apt upgrade`. The `-4` flag is really only needed for the 02 script to avoid the inverse problem when IPv6 is stopped.

* 2024-01-13

	- Bump default version of docker-compose installed via script to v2.24.0.

* 2023-12-29

	- Add avahi daemon to list of PiBuilder dependencies in 01 script. This is needed for PiBuilder installs on Ubuntu.
	- Add functions to detect running Linux distro.
	- When omitted, `SKIP_FULL_UPGRADE` now defaults to false on Debian, true on non-Debian (eg Ubuntu). This is a workaround for a problem where Ubuntu seems to hang on full upgrades.
	- `DEBIAN_BOOKWORM_UPGRADE` (added 2023-07-03) removed. At that time the Raspberry Pi releases page only had Bullseye images so the only way to get Bookworm was to start with Bullseye and upgrade. That is no longer the case so this control is redundant.

* 2023-12-18

	- Git clone commands in 03 script now default to:

		``` console
		$ git clone --filter=tree:0
		```

		Documentation at [about Git options](./README-ADVANCED.md#aboutGitOptions).

* 2023-12-11

	- `hopenpgp-tools` package removed from dependency list in 03 script. See [About `hopenpgp-tools`](./docs/hopenpgp-tools.md) for more information.
	- support second argument to `install_packages()` function so as to make primary dependencies (those actually needed for IOTstack) mandatory (as now) with the crypto dependencies optional.

* 2023-11-23

	- Bump default version of docker-compose installed via script to v2.23.2; and then again (same day) to v2.23.3.

* 2023-11-17

	- Bump default version of docker-compose installed via script to v2.23.1
	- Prune change-log entries prior to 2023.

* 2023-11-01

	- Rewrite [original build method](./README-ADVANCED.md#originalBuild) material to cater for Bookworm.
	- Update `running_OS_build()` function to allow for change to where `issue.txt` file is stored in Bookworm.

* 2023-10-29

	- Supports the following environment variables in either options.sh, or inline on the call to the 03 and 04 scripts, or exported to the environment before calling those scripts:

		variable                 | default
		-------------------------|----------------------------------------------------
		`IOTSTACK`               | `$HOME/IOTstack`
		`IOTSTACK_URL`           | `https://github.com/SensorsIot/IOTstack.git`
		`IOTSTACK_BRANCH`        | `master`
		`IOTSTACKALIASES_URL`    | `https://github.com/Paraphraser/IOTstackAliases.git`
		`IOTSTACKALIASES_BRANCH` | `master`
		`IOTSTACKBACKUP_URL`     | `https://github.com/Paraphraser/IOTstackBackup.git`
		`IOTSTACKBACKUP_BRANCH`  | `master`

	- `IOTSTACK` allows the installation folder to be something other than `~/IOTstack` while the others permit cloning from forks or copies of the relevant repositories.
	- Explanation of above added to [Advanced README](./README-ADVANCED.md#envVarOverrides) 
	- Removed installation of `sshfs` from 03 script (deprecated upstream).

* 2023-10-22

	- Adds `set_hostname.sh` helper script. This mimics (in part) the approach of `raspi-config` to changing the hostname but augments it with a best-efforts discovery of any local domain name which may have been learned from DHCP. Taken together, this is closer to the result obtained from running the Debian ISO installer. It results in `/etc/hosts` gaining a fully-qualified domain name and that, in turn, means the `hostname -d` and `hostname -f` commands work.

		> for anyone following along at home, the problem with `hostname -d` and `-f` not working because `/etc/hosts` lacked an FQDN was a chance discovery while attempting to add ownCloud to IOTstack. It worked properly in a Debian guest on Proxmox but not on the Pi.

	- Change-of-hostname functionality in the 01 script now implemented by invoking `set_hostname.sh`.


* 2023-10-20

	- Bump default version of docker-compose installed via script to v2.23.0

* 2023-10-06

	- Remove patch added 2023-08-02 which removes pins from Python requirements files using `sed`. Now that [PR 723](https://github.com/SensorsIot/IOTstack/pull/723) has been applied, this is no longer needed.

* 2023-10-03

	- Reset `exim4` paniclog if non-zero length.
	- Expands [Proxmox tutorial](./docs/running-on-proxmox-debian.md) to discuss migrating an IOTstack instance (eg from a Raspberry Pi to a Debian guest).

* 2023-09-23

	- Bump default version of docker-compose installed via script to v2.22.0

* 2023-09-22

	- Incorporates feedback from Andreas on [tutorial](./docs/running-on-proxmox-debian.md).

* 2023-09-17

	- Adds a [tutorial](./docs/running-on-proxmox-debian.md) for installing a Debian guest on a Proxmox&nbsp;VE instance, then running PiBuilder, and then getting started with IOTstack.

* 2023-08-31

	- Add check for pre-existing IOTstack folder at start of 03 script.
	- Bump default version of docker-compose installed via script to v2.21.0
	- Adds `apt update` to start of 03 script to guard against any significant delays between running the 01 and 03 scripts.
	- Adds check to 04 script to detect absence of the IOTstack folder. When doing a full PiBuilder run, the most likely reasons why the IOTstack folder will not exist are:

		* because one or more `apt install «package»` commands failed and the user didn't realise the 03 script is designed so that it can be run over and over until all dependencies are installed, after which 03 then clones IOTstack; or
		* because the 04 script is being run in isolation, just to get docker and docker-compose installed and have the other IOTstack-specific spadework done (docker group, Python prerequistes, etc).

	- Adds `-c` option (3 context lines) to patch generation in [NTP tutorial](docs/ntp.md). Needed so patches will succeed on both Bullseye and Bookworm.

* 2023-08-22

	- Better handling of `hopenpgp-tools` on Bookworm, per [DrDuh PR386](https://github.com/drduh/YubiKey-Guide/pull/386).

* 2023-08-21

	- Adds support for GRUB-based boots. Default patch disables IPv6.
	- Improved handling of python3-ykman (not available on Buster).
	- Bump SQLite version to 3420000.

* 2023-08-13

	- Bump default version of docker-compose installed via script to v2.20.3

* 2023-08-08

	- Tested PiBuilder on Ubuntu Jammy guest under Proxmox.
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
