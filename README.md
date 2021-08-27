# PiBuilder

## Introduction

This project documents my approach to building a working Raspberry Pi operating system "from the ground up".

I am putting this material on GitHub in response to several requests to share my approach. Before using this project, you need to understand:

1. The scripts and supporting files implement **my** requirements for **my** Raspberry Pis. The material is **not** intended to be "one size fits all" for all possible Raspberry Pi configurations. You will almost certainly need to make adjustments for your own situation.
2. It is highly **unlikely** that the scripts and supporting files will work "as is" on your system. You **will** need to customise this material and you **will** need to know what you are doing.
3. I can't promise to fix any bugs.
4. I can't promise to keep this project maintained.

<hr>

- [Caveats and assumptions](#caveats)
- [Design goals](#goals)
- [Recommended approach](#recommendedApproach)
- [Script synopses](#synopses)

	- [Script `01_setup.sh`](#script01)
	- [Script `02_setup.sh`](#script02)
	- [Script `03_setup.sh`](#script03) – ***now with hass.io option***
	- [Script `04_setup.sh`](#script04)
	- [Script `05_setup.sh`](#script05)

- [Building a Rapberry Pi using these scripts](#buildSequence)
- [Beware of chickens and eggs](#chickenEgg)
- [Some words about SSH](#aboutSSH)

	- [About `/etc/ssh`](#aboutEtcSSH)
	- [About `~/.ssh`](#aboutDotSSH)
	- [Security of snapshots](#snapshotSecurity)

<hr>

## <a name="caveats"> Caveats and assumptions </a>

The material in this project assumes and has been tested on:

* Raspberry Pi 3B+ and 4B hardware
* Raspberry Pi OS (aka Raspbian)

The scripts **may** work on other Raspberry Pi hardware but I have no idea about other hardware platforms or operating systems, even if they claim to run on Raspberry Pi hardware.

> I have nothing against either non- Raspberry Pi hardware or operating systems. I just want to make it clear that I can only test using the hardware I have.

## <a name="goals"> Design goals </a>

My design goals were:

1. To have a reliable, repeatable and auditable approach to building a Raspberry Pi OS, from the ground up, primarily as a support platform for [SensorsIot/IOTstack](https://github.com/SensorsIot/IOTstack).
2. Insofar as was possible, eliminate the need for interaction. I don't want "yes/no" prompts. I don't want to interact with menus like `raspi-config`. I want **speed**.
3. All work done via ssh. I do not have an HDMI screen and I don't run VNC. I'm a command-line geek.

## <a name="recommendedApproach"> Recommended approach </a>

1. I recommend downloading this project as a zip.

	> You can clone the repo if you wish but that sort of implies you expect to receive updates. The problem is that you *will* have to mod these scripts. If you make your mods in a clone of the repo, your mods will block updates coming down from GitHub. To deal with that, you will need a "working copy" where it is safe to make your own mods. Which is sort of what you get by starting from a zip.
2. Unpack the zip.
3. Work through the scripts to see what they do and customise them to your needs. In some cases:

	- It can be as simple as changing the right hand side of environment variables. For example (from `01_setup.sh`):

		```bash
		LOCALCC="AU"
		LOCALTZ="Australia/Sydney"
		```

	- In other cases, you will need to edit more carefully. The text below (also from `01_setup.sh`) is building a temporary file in RAM which is creating editing **instructions** for later use:
	
		```bash
		LOCALE_EDITS="$(mktemp -p /dev/shm/)"
		cat <<-LOCALE_EDITS >"$LOCALE_EDITS"
		s/^#.*en_AU ISO-8859-1/en_AU ISO-8859-1/
		s/^#.*en_AU.UTF-8 UTF-8/en_AU.UTF-8 UTF-8/
		s/^en_GB.UTF-8 UTF-8/# en_GB.UTF-8 UTF-8/
		s/^#.*en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/
		LOCALE_EDITS
		```
		
		Those instructions are (in order):
		
		* Find the commented-out "en_AU ISO-8859-1" and un-comment.
		* Find the commented-out "en_AU.UTF-8 UTF-8" and un-comment.
		* Find the active "en_GB.UTF-8 UTF-8" and comment it out.
		* Find the commented-out "en_US.UTF-8 UTF-8" and un-comment.
		
		The script line **after** that uses the temporary file:
		
		```bash
		$ sudo sed -i.bak -f "$LOCALE_EDITS" /etc/locale.gen
		```
		
		The `-i.bak` tells `sed` to edit the file in-situ but save the original file with a `.bak` extension. To test, you can create the "LOCALE_EDITS" as above but then run the `sed` command like this:
		
		```bash
		$ sed -f "$LOCALE_EDITS" /etc/locale.gen >edited-locale.gen
		$ diff /etc/locale.gen edited-locale.gen
		```
		
		Running `sed` like that doesn't change the original. Then you can compare the unmodified original with the edited version to see if it is correct.
	
	- You will need to decide, case by case, whether you want to adopt a particular "feature". An example is at the end of `02_setup.sh` where IPv6 is turned off. Do you want IPv6 enabled or turned off?
	- Another example is the additional packages in `02_setup.sh`. They are broken into two groups. The first group should almost certainly be installed on all systems. The second group is under the "YubiKey" heading but only *some* of those are needed for the YubiKey while others are needed for GnuPG. You may not have a YubiKey but that doesn't mean GnuPG can't be useful all by itself.
	
		> see the excellent [Dr Duh guide](https://github.com/drduh/YubiKey-Guide) if you want to set up a YubiKey and use it to digitally sign your GitHub commits.
	
4. Work through the files in the `support` directory:

	```
	99-usb-serial.rules ✅
	common.custom 🚫 (DON'T add password!)
	debian-backports.list 🚫
	dhcpcd.conf.patch 🚫
	dot-gitconfig 👁‍🗨
	dot-gitignore_global 🚫
	gpg-owner-trust.txt 👁‍🗨
	iotstack_backup-config.yml 👁‍🗨
	isc-dhcp-fix.sh ✅
	rc.local.patch 🚫
	rclone.conf 👁‍🗨
	resolvconf.conf.patch ✅
	sysctl.conf.patch 🚫
	timesyncd.conf.patch 👁‍🗨
	User.crontab ✅
	User.profile ✅
	```
	
	Key:
	
	* ✅ optional - can be edited or left as-is
	* 🚫 OK in its current form - no need to edit (be sure you know what you're doing)
	* 👁‍🗨 should be customised
	
	You might want to read [beware of chickens and eggs](#chickenEgg) as you think about what should be in these files.
	
5. Edit to set your WiFi network name (SSID) and join password:
	
	```
	wpa_supplicant.conf 👁‍🗨
	```
	
6. Read [some words about SSH](#aboutSSH) and decide if you wish to take snapshots and add the resulting `.tar.gz` files to the `support` directory.
	
## <a name="synopses"> Script synopses </a>

### <a name="script01"> Script `01_setup.sh` </a>

* Assumes fresh install of Raspberry Pi OS.
* Adds support for fetching libseccomp2 from Debian Buster backports (needed for Alpine-based Docker images).
* Runs full OS update/upgrade.
* Snapshots `/etc` as `/etc-baseline` (a baseline reference).
* Optionally replaces `/etc/ssh` with a preset.
* Sets the user password.
* Sets up VNC with the same password (but does NOT activate VNC)
* Sets up locale.
* Sets raspi-config options:

	- boot to console
	- WiFi country code
	- TimeZone
	- Machine name

* Reboots

### <a name="script02"> Script `02_setup.sh` </a>

* Cleans up any leftovers from `/etc/ssh` replacement.
* Applies recommended `allowinterfaces eth*,wlan*` patch.
* Applies [Does your Raspberry Pi's Wireless Interface freeze?](https://gist.github.com/Paraphraser/305f7c70e798a844d25293d496916e77). You may need to edit `isc-dhcp-fix.sh` if you don't have both Ethernet and WiFi interfaces active.
* Sets up local DNS (does nothing if you don't edit `resolvconf.conf.patch`)
* Disables IPv6
* Reboots

### <a name="script03"> Script `03_setup.sh` </a>

* Installs add-on packages, including backports libseccomp2.
* Sets up Network Time Protocol sync with local time-servers. See [Configuring Raspbian to use local time-servers](https://gist.github.com/Paraphraser/e1129880015203c29f5e1376c6ca4a08).
* Replaces `~/.profile`
* Initialises crontab
* Clones old-menu branch of [SensorsIot/IOTstack](https://github.com/SensorsIot/IOTstack).
* Installs IOTstack dependencies.
* Clones [IOTstackAliases](https://github.com/Paraphraser/IOTstackAliases)
* Makes Python3 the default.
* Installs IOTstackBackup dependencies.
* Clones and installs [IOTstackBackup](https://github.com/Paraphraser/IOTstackBackup)
* Copies support files for `rclone` and IOTstackBackup into `~/.config`
* Reboots

#### <a name="script03hassio"> hass.io option </a>

In its default form, `03_setup.sh` assumes `hass.io` is not to be installed. However, if you edit the script to enable **one** of the following lines:

```bash
#HASSIO_ARCHITECTURE="raspberrypi4-64"
#HASSIO_ARCHITECTURE="raspberrypi4"
#HASSIO_ARCHITECTURE="raspberrypi3-64"
#HASSIO_ARCHITECTURE="raspberrypi3"
``` 

before running the script then `hass.io` will be installed. Note, however, that the installer script will wait for you to respond to the following prompt:

```
Changes are needed to the /etc/network/interfaces file
```

Press <kbd>y</kbd> then <kbd>enter</kbd>.

### <a name="script04"> Script `04_setup.sh` (optional but recommended) </a>

* Sets up git scaffolding.
* Imports GPG public key from key-server and assigns trust.
* Sets up ssh (if you supply a script to do it).
* Adds `mkdocs` support. With that in place, you can do:

	```bash
	$ cd ~/IOTstack
	$ mkdocs serve -a «ipaddress»:«port»
	```

	where «ipaddress» is the IP address of your Raspberry Pi, and «port» is a port not otherwise in use (eg 9780). Then, from another host you can point your browser at:
	
	```
	http://«ipaddress»:«port»
	```
	
	and see the Wiki view of the IOTstack documentation.
	
* Erases bash history.
* Logs out

### <a name="script05">Script `05_setup.sh` (fully optional)</a>

* Rebuilds SQLite from source code. The one you get from `apt install` doesn't have all the features you might want.

## <a name="buildSequence"> Building a Rapberry Pi using these scripts </a>

Assuming you have done all the necessary customisation…

1. Go to [Operating system images](https://www.raspberrypi.org/software/operating-systems/) and download "Raspberry Pi OS with desktop".

	> I always start from the "Mamma Bear" image. I have never tried the "Papa Bear" or "Baby Bear" images. I honestly don't know whether the other images will "just work" or will cause problems.
		
2. Use [BalenaEtcher](https://www.balena.io/etcher/) to image an SD or SSD. The latter is recommended. Generally, that results in the `/boot` volume being dismounted at the end. Re-mount it.
3. Run `setup_boot_volume.sh`. That copies `ssh` (an empty file), `wpa_supplicant.conf` (which you should have edited) and the contents of the `scripts` directory (including the `support` sub-directory) to the boot volume. I do this on a Mac. I have no idea whether it works on Windows (you could probably use drag-and-drop).
4. Dismount the `/boot` volume. Insert (SD) or connect (SSD) the media to the RPi, apply power, and wait for it to boot up.
5. Connect to the Raspberry Pi:

	```bash
	$ ssh pi@raspberrypi.local
	```

	Note:
	
	* "raspberrypi" is the default name. Even if you only have a single Raspberry Pi, you should always give it a name that is unique on your network. You have only yourself to blame if you ever get into the situation where two or more Raspberry Pis are using the same name. It will confused both you and your Raspberry Pis.

6. Your ssh client will present the Trust On First Use (TOFU) pattern where it asks for authority to proceed and then prompts for the password for user "pi" on the target machine, which is:

	```
	raspberry
	```
	
7. Run the first script using one of the following forms:

	- Supply both the hostname and password as parameters

		```bash
		$ /boot/scripts/01_setup.sh «hostname» «password»
		```
		
	- Supply the hostname as a parameter and be prompted for the password:

		```bash
		$ /boot/scripts/01_setup.sh «hostname»
		```
		
	Notes:
	
	* «hostname» is the name your RPi will be known by (and for heaven's sake, **don't** use "raspberrypi")
	* «password» is the new password for user "pi" on the target machine. For obvious reasons, it should be something other than "raspberry".

	The script ends with a reboot, which will terminate your ssh client.
	
8. Back on your support host (Mac, PC, whatever) erase the TOFU evidence:

	```bash
	$ ssh-keygen -R raspberrypi.local
	```
	
	What that does is to remove the association between the name "raspberrypi.local" and the keys for this particular target RPi. If you don't do this then you will get a mess the next time you want to login to this host, or any other host, using the name "raspberrypi.local". Be tidy! Clean up your workspace as you go!
	
9. When the Pi comes back from the reboot:

	```bash
	$ ssh pi@«hostname»
	```
	
	Exactly what you use after the "@" depends on how things work in your home network. You can try:
	
	* «hostname».local
	* «hostname».your.domain.com
	* the IP address of the RPi

	Whether you see the TOFU pattern again, or whether you are prompted for the new password for user "pi" depends on whether you have previously set up a scheme of ssh keys and certificates. Just deal with the situation as it presents itself.
	
10. Run the second script:

	```bash
	$ /boot/scripts/02_setup.sh
	```
	
	This script ends in a reboot. Wait for the Pi to come back from the reboot and login as above.

11. Run the third script:

	See also the notes above about [enabling hass.io](#script03hassio) as an installation optional.


	```bash
	$ /boot/scripts/03_setup.sh
	```
	
	A common problem with this script is the error "Unable to connect to raspbian.raspberrypi.org". This seems to be transient but it also happens far more frequently than you would like or expect. The script attempts to work around this problem by processing each package individually, and keeping track of packages that could not be installed. Then, if there are any packages that could not be installed, the script:
	
	- displays a list of the failed packages;
	- invites you to try running the failed installations by hand; and
	- asks you to re-run 03_setup.sh (which will skip over any packages that are already installed).

	Remember:
	
	* if you [enable hass.io](#script03hassio) then the script will pause waiting for you to confirm that it is OK to overwrite `/etc/network/interfaces`.

	This script also ends in a reboot. Wait for the Pi to come back from the reboot and login as above.
	
	At this point, the RPi should be ready to run an `iotstack_restore`. If you don't have a backup ready to be reloaded, you can just run the IOTstack menu and choose your containers.

10. Run the fourth script:

	This is optional. It is mainly about user-side customisation like git scaffolding, GnuPG and ssh client (ie if the Pi is the client in an SSH session connecting to another host). 

	```bash
	$ /boot/scripts/04_setup.sh
	```
	
	The script finishes off by clearing the `bash` history, which goes some way to removing the password supplied as an argument to the first script. If you don't want to run this script, you might still want to think about running:
	
	```bash
	$ history -c
	```

10. Run the fifth script:

	This is *completely* optional. It just installs SQLite from source code. It has a high level of interdependence on decisions taken by the folks at SQLite. In particular, these variables:
	
	```bash
	SQLITEYEAR="2021"
	SQLITEVERSION="sqlite-autoconf-3350000"
	SQLITEURL="https://www.sqlite.org/$SQLITEYEAR/$SQLITEVERSION.tar.gz"
	```
	
	The only way to find out when those change is to visit [www.sqlite.org/download.html](https://www.sqlite.org/download.html).
	
	If you want to build SQLite:
	
	```bash
	$ /boot/scripts/05_setup.sh
	```

## <a name="chickenEgg"> Beware of chickens and eggs </a>

Installing and configuring software on a Raspberry Pi (or any computer) involves quite a few chicken-and-egg situations. For example:

* Until you decide to install [IOTstackBackup](https://github.com/Paraphraser/IOTstackBackup), you:

	- May not have had a need to install `rclone`
	- May not have had to configure `rclone` to use Dropbox as a remote
	- Will not have had to think about configuring `iotstack_backup`.

* If you decide to install IOTstackBackup then you will need to think about all those things.
* Once you have obtained an "app key" for Dropbox, have established an `rclone` remote to talk to Dropbox, and have configured IOTstackBackup to use that remote, you will expect to be able to take backups, and then restore those backups on your Raspberry Pi. And you will…
* … until you rebuild your Raspberry Pi. To be able to restore after a rebuild, you **must** have the `rclone` and `iotstack_backup` configurations in place. You either need to:

	- recreate those by hand (and obtain a new Dropbox app key), or
	- recover them from somewhere else (eg another RPi), or
	- make sure they are in the right place for this build process to be able to copy them into place automatically at the right time.

* This repo assumes the last option: you have saved the `rclone` and `iotstack_backup` configuration files into the `support` subdirectory.
* Of course, in order to have saved those configurations in the `support` subdirectory, you will first have had to have set them up and tested them.

Chicken-and-egg!

There are quite a few of these. The `99-usb-serial.rules` is another example. You need to know all your USB devices, have figured out their parameters, and have added the directives to this file **before** you want to use it as part of a rebuild.

There is no substitute for thinking, planning and testing.

## <a name="aboutSSH"> Some words about SSH </a>

### <a name="aboutEtcSSH"> About `/etc/ssh` </a>

Whenever you start from a clean Raspberry Pi OS image (BalenaEtcher), the very first boot-up initialises the contents of:

```
/etc/ssh
```

The contents of that folder can be thought of as a unique identity for the SSH service on your Raspberry Pi. That "identity" can be captured by running the following script in the `helpers` folder:

```bash
$ ./etc_ssh_backup.sh
```

Suppose you gave the RPi the name "fred" then the result of running that script will be:

```
~/fred.etc-ssh-backup.tar.gz
```

If you copy that file into the `support` folder **before** you run `setup_boot_volume.sh` then that `.tar.gz` will be copied onto the `boot` volume along with everything else.

Then, when it comes time to run the first script and you do:

```bash
$ /boot/scripts/01_setup.sh fred «password»
``` 

the script will look for `fred.etc-ssh-backup.tar.gz` and, if found, will use it to restore `/etc/ssh` as it was at the time the snapshot was taken. In effect, you have given the machine its original SSH identity.

The contents of `/etc/ssh` are not tied to the physical hardware so if, for example, your "live" RPi emits magic smoke and you have to repurpose your "test" RPi, you can cause the replacement to take on the SSH identity of the failed hardware.

> Fairly obviously, you will still need to do things like change your DHCP server so that the working hardware gets the IP address(es) of the failed hardware, but the SSH side of things will be in place.

Whether you do this for any or all of your hosts is entirely up to you. I have gone to the trouble of setting up ssh certificates and it is a real pain to have to run around and re-sign the host keys every time I rebuild a Raspberry Pi. It is much easier to set up `/etc/ssh` **once**, then take a snapshot, and re-use the snapshot each time I rebuild.

The *practical* effect of this is that my build sequence begins with:

```bash
$ ssh pi@raspberrypi.local
raspberry
$ /boot/scripts/01_setup.sh previousname «password»
$ ssh-keygen -R raspberrypi.local
$ ssh previousname
…
```

No `pi@` on the front. No `.local` or domain name on the end. No TOFU pattern. No password prompt. Just logged-in.

### <a name="aboutDotSSH"> About `~/.ssh` </a>

The contents of `~/.ssh` carry the client identity (how "pi" authenticates to target hosts), as distinct from the machine identity (how the RPi proves itself to clients seeking to connect).

Personally, I use a different approach to maintain and manage `~/.ssh` but it is still perfectly valid to run the supplied:

```bash
$ user_ssh_backup.sh
``` 

and then restore the snapshot in the same way as `01_setup.sh` does for `/etc/ssh`. I haven't provided a solution in this repository. You will have to come up with that for yourself.

### <a name="snapshotSecurity"> Security of snapshots </a>

There is an assumption that it is "hard" for an unauthorised person to gain access to `etc/ssh` and, to a lesser extent, `~/.ssh`. How "hard" that actually is depends on a lot of things, not the least of which is whether you are in the habit of leaving terminal sessions unattended.......

Nevertheless, it is important to be aware that the snapshots do contain sufficient information to allow a third party to impersonate your hosts so it is probably worthwhile making some attempt to keep them reasonably secure.

I keep my version of all of these scripts and the associated `/etc/ssh` snapshot files on an encrypted volume. You may wish to do the same.
