# PiBuilder

## <a name="introduction"> Introduction </a>

This project documents my approach to building Raspberry Pi operating systems to support [SensorsIot/IOTstack](https://github.com/SensorsIot/IOTstack).

Design goals:

1. To have a reliable, repeatable and auditable approach to building Raspberry Pi OS, primarily as a support platform for [SensorsIot/IOTstack](https://github.com/SensorsIot/IOTstack).
2. As far as possible, to favour **speed** over any need for interaction during the build process.
3. All work done "headless" via ssh.

PiBuilder can't possibly be a "one size fits all" for all possible Raspberry Pi configurations. Of necessity, the scripts and supporting files implement *my* decisions and assumptions. You will almost certainly need to make adjustments for your own situation, and I have tried to make allowances for that by providing a patching system that is flexible and extensible.

I have tested PiBuilder on:

* Raspberry Pi 3B+, 4B and Zero W2 hardware
* 32-bit versions of Raspberry Pi OS (aka Raspbian) "Buster" and "Bullseye"
* 64-bit version of "Bullseye".

The scripts will *probably* work on other Raspberry Pi hardware but I have no idea about other hardware platforms (eg Nuc) or operating systems (eg Debian). I have nothing against either non- Raspberry Pi hardware or operating systems. I can only test with what I have.

## <a name="toc"> Contents </a>

- [Definitions](#definitions)
- [Build process summary](#buildProcessSummary)
- [The build process in detail](#buildProcessDetailed)

	- [Download this repository](#downloadRepo)
	- [Choose an imaging tool](#chooseTool)
	- [Choose and download a base image](#chooseImage)

		- [option 1 – Raspbian Bullseye (32-bit)](#chooseRaspbianBullseye)
		- [option 2 – Raspbian Buster (32-bit)](#chooseRaspbianBuster)
		- [option 3 – Debian Bullseye (64-bit)](#chooseDebianBullseye)

	- [Transfer Raspbian image to SD or SSD](#burnImage)
	- [PiBuilder configuration](#configPiBuilder)

		- [Configure WiFi](#configWiFi)
		- [Configure installation options](#configOptions)
		- [Git user configuration](#configGit)

	- [Run the PiBuilder setup script](#setupPiBuilder)
	- [Boot your Raspberry Pi](#bootRPi)
	- [Run the PiBuilder scripts in order](#runScripts)

		- [Script 01](#runScript01)
		- [Script 02](#runScript02)
		- [Script 03](#runScript03)
		- [Script 04](#runScript04)
		- [Script 05](#runScript05)
		- [Script 06 (optional)](#runScript06)

- [Script summaries](#synopses)

	- [Script 01](#docScript01)
	- [Script 02](#docScript02)
	- [Script 03](#docScript03)
	- [Script 04](#docScript04)
	- [Script 05](#docScript05)
	- [Script 06 (optional)](#docScript06)

- [How PiBuilder scripts search for files, folders and patches](#scriptSearch)

	- [Search function – `supporting_file()`](#searchForItem)
	- [Patch function – `try_patch()`](#searchForPatch)

- [Preparing your own patches](#patchPreparation)

	- [Tools overview: *diff* and *patch*](#patchTools)
	- [Basic process](#patchSummary)
	- [Tutorials](#patchTutorials)

- [Keeping in sync with GitHub](#moreGit)
- [Beware of chickens and eggs](#chickenEgg)

- [Some words about SSH](#aboutSSH)

	- [About `/etc/ssh`](#aboutEtcSSH)
	- [About `~/.ssh`](#aboutDotSSH)
	- [Security of snapshots](#snapshotSecurity)

- [Change Summary](#changeLog)

## <a name="definitions"> Definitions </a>

* "your support host" means the system where you have cloned the PiBuilder repository. It will usually be a Mac or PC.
* "`~/PiBuilder`" means the path to the directory where you have cloned the PiBuilder repository from GitHub onto your support host. The directory does not have to be in your home directory on your support host. It can be anywhere.
* "your Raspberry Pi" means the Raspberry Pi device for which you are building an operating system using PiBuilder.
* "iot-hub" is the example hostname for your Raspberry Pi. You can choose any name you like for your Raspberry Pi (save that "raspberrypi" is not recommended). Just substitute the name of your Raspberry Pi wherever you see "iot-hub".

## <a name="buildProcessSummary"> Build process summary </a>

1. Download this repository.
2. Choose an imaging tool.
3. Choose a Raspbian image.
4. Use the imaging tool to transfer the Raspbian image to your media (SD card or SSD).
5. Configure PiBuilder.
6. Run the PiBuilder `setup_boot_volume.sh` script to add installation files to the media.
7. Move the media to your Raspberry Pi and apply power.
8. Connect to your Raspberry Pi using SSH and run the PiBuilder scripts in order.

The end point is a system with IOTstack and all dependencies installed. You can either start building a Docker stack using the IOTstack menu or restore an IOTstack backup.

Please don't be put off by the length of this README document. You can start using PiBuilder without having to worry about any customisations. You will get a Raspberry Pi that is a solid foundation for IOTstack.

Later, when you start to customise your Raspberry Pi, you will realise that you might have trouble remembering all the steps if you ever have to rebuild your Raspberry Pi in a hurry (failed SD card; magic smoke; operator error). That's when the true power of PiBuilder will start to become apparent. You can dig into the how-to when you are ready.

## <a name="buildProcessDetailed"> The build process in detail </a>

### <a name="downloadRepo"> Download this repository </a>

1. Download this repository from GitHub:

	```bash
	$ git clone https://github.com/Paraphraser/PiBuilder.git ~/PiBuilder
	```

	You don't have to keep the PiBuilder folder in your home directory. It can be anywhere. Just remember the [definition](#definitions) that `~/PiBuilder` always means "the path to the PiBuilder folder on your support host".

2. Create a branch to keep track of your changes:

	```bash
	$ cd ~/PiBuilder
	$ git checkout -b custom
	```

	> You don't have to call your branch "custom". You can choose any name you like.

	A dedicated branch helps you to keep your own changes separate from any changes made to the master version on GitHub, and makes it a bit simpler to manage merging if a change you make conflicts with a change coming from GitHub.

### <a name="chooseTool"> Choose an imaging tool </a>

I use and recommend [Raspberry Pi Imager](https://www.raspberrypi.com/software/). The instructions below assume you are using Raspberry Pi Imager.

> [BalenaEtcher](https://www.balena.io/etcher/) is an alternative that does a similar job.

### <a name="chooseImage"> Choose and download a base image </a>

Images for the Raspberry Pi are downloaded as `.zip` files. In all cases, you always have the choice of:

1. downloading the `.zip` *directly;* or
2. downloading the `.zip` *indirectly* by starting with the `.torrent`.

It is always a good idea to check the SHA256 signature on each zip. It gives you assurance that the image has not been tampered with and wasn't corrupted during download. The magic incantation is:

```bash
$ SIGNATURE=«hash»
$ IMAGE=«pathToZip»
$ shasum -a 256 -c <<< "$SIGNATURE *$IMAGE"
```

You get the «hash» either by clicking the `Show SHA256 file integrity hash` link or by downloading and inspecting the `.zip.sha256` associated with the `.zip`. Here's an example:

```bash
$ SIGNATURE=6e9faca69564c47702d4564b2b15997b87d60483aceef7905ef20ba63b9c6b2b
$ IMAGE=./2021-10-30-raspios-bullseye-armhf.zip
$ shasum -a 256 -c <<< "$SIGNATURE *$IMAGE"
./2021-10-30-raspios-bullseye-armhf.zip: OK
```

If you don't see "OK", start over!

> If your first attempt was a *direct* download of the `.zip`, consider trying the *indirect* method using a torrent.

I recommend unpacking each `.zip` to a `.img`. While it is true that the imaging tools can use the `.zip` files, it takes a bit longer because the `.zip` still has to be unpacked each time.

##### *on the topic of 32- vs 64-bit …*

* "32-bit" systems:

	- Are capable of running both 32-bit and 64-bit kernels. See also the PiBuilder option: [`PREFER_64BIT_KERNEL`](#prefer64BitKernel).
	- User mode is fixed to 32-bit.
	- Docker will pull images built for "arm" architecture.

	The ability to switch kernel modes can come in handy if you find a container misbehaving under a 64-bit kernel.

* "64-bit" systems:

	- Run 64-bit in both kernel and user modes.
	- Docker will pull images built for "arm64" architecture.

	Once you are running full 64-bit, you have no ability to chop and change.

#### <a name="chooseRaspbianBullseye"> option 1 – Raspbian Bullseye (32-bit) </a>

The most recent Raspberry Pi OS can always be found at the link below. Currently, this leads to the 32-bit version of Raspbian Bullseye:

* [https://www.raspberrypi.com/software/operating-systems/](https://www.raspberrypi.com/software/operating-systems/)

I always start from "Raspberry Pi OS with desktop" so that is what I recommend.

At the time of writing (November 2021), this is the initial release of "Raspbian Bullseye". It was made available on 2021-10-30 and is not necessarily "proven" or "stable" or "well understood". In particular, if you need camera support, you might be better advised to stick with [Raspbian Buster (32-bit)](#chooseRaspbianBuster).

#### <a name="chooseRaspbianBuster"> option 2 – Raspbian Buster (32-bit) </a>

If you would prefer to base all your work on a system that **can** be considered proven, stable and well-understood, you should consider "Raspbian Buster". It is a 32-bit system which can be downloaded from:

* [http://downloads.raspberrypi.org/raspios_armhf/images/raspios_armhf-2021-05-28/](http://downloads.raspberrypi.org/raspios_armhf/images/raspios_armhf-2021-05-28/)

#### <a name="chooseDebianBullseye"> option 3 – Debian Bullseye (64-bit) </a>

This is a full 64-bit alternative to [Raspbian Bullseye (32-bit)](#chooseRaspbianBullseye). It installs, looks, feels and behaves like Raspbian but it self-identifies as "Debian". You can download it from:

* [http://downloads.raspberrypi.org/raspios_arm64/images/raspios_arm64-2021-11-08/](http://downloads.raspberrypi.org/raspios_arm64/images/raspios_arm64-2021-11-08/)

Key points:

* Please be **cautious** when using this image. PiBuilder will install 64-bit versions of everything, including docker, docker-compose and Supervised Home Assistant, and Docker will pull "arm64" images when you bring up your stack. Just because something *installs* without error does not guarantee that it will *run* correctly. If you decide to upgrade from a 32-bit system, you will need to assure yourself that all your containers still work as expected. Please don't pick this image as your starting point for no better reason than "64-bit must be better than 32-bit" because your mileage may vary.
* It is not clear why this image self-identifies as "Debian" rather than "Raspbian" or "Raspberry Pi OS". It might be a subtle hint that it isn't fully supported by the Raspberry Pi Foundation.

### <a name="burnImage"> Transfer Raspbian image to SD or SSD </a>

The steps are:

1. Connect your media (SD or SSD) to your support platform (eg Mac/PC). 
2. Launch Raspberry Pi Imager.
3. Click <kbd>CHOOSE OS</kbd>.
4. Scroll down and choose "Use custom".
5. Select the `.img` (or `.zip`) you downloaded earlier.
6. Click <kbd>CHOOSE STORAGE</kbd>
7. Select the media connected in step 1. *Be careful with this step!*
8. Click <kbd>WRITE</kbd>.

At the end of the process, Raspberry Pi Imager ejects your media (BalenaEtcher does the same).

### <a name="configPiBuilder"> PiBuilder configuration </a>

#### <a name="configWiFi"> Configure WiFi </a>

Use a text editor to open the following file:

```
~/PiBuilder/boot/wpa_supplicant.conf
```

The file supplied with PiBuilder looks like this:

```
# set your country code, WiFi SSID and pre-shared key here.
# if you DON'T want to enable WiFi, just delete this file.
country=«CC»
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="«SSID»"
    psk="«PSK»"
}
```

You should replace three values:

1. `«CC»` with your two-character country code (eg `AU`).
2. `«SSID»` with your WiFi Service Set IDentifier (otherwise known as the name of your WiFi network).
3. `«PSK»` with your Pre-Shared Key (otherwise known as the join password for your WiFi network).

Unless you change your WiFi password frequently, you should only need to edit this file once. The configuration can be re-used for all of your Raspberry Pis.
 
#### <a name="configOptions"> Configure PiBuilder installation options </a>

Use a text editor to open:

```
~/PiBuilder/boot/scripts/support/pibuilder/options.sh
```

The file supplied with PiBuilder looks like this:

```bash
# this file is "sourced" in all build scripts.

# - country-code for WiFi
LOCALCC="AU"

# - local time-zone
LOCALTZ="Etc/UTC"

# - preference for kernel. Only applies to 32-bit installations. If
#   true, adds "arm_64bit=1" to /boot/config.txt
PREFER_64BIT_KERNEL=false

# - default language
#   Whatever you change this to must be in your list of active locales
#   (set via ~/PiBuilder/boot/scripts/support/etc/locale.gen.patch)
#LOCALE_LANG="en_GB.UTF-8"

# - override for docker-compose version number. See:
#     https://github.com/docker/compose/releases
#DOCKER_COMPOSE_VERSION="v2.2.2"
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
SQLITEVERSION="sqlite-autoconf-3370000"
```

You **should** set:

1. The right hand side of `LOCALCC` to your two-character country code. This should be the same value you used in `wpa_supplicant.conf`.
2. The right hand side of `LOCALTZ` to a valid country and city combination. It is OK to leave this alone if you are not certain about the correct values.

You **can** set:

1. The right hand side of `LOCALE_LANG` to a valid language descriptor but any value you set here **must** also be enabled via a locale patch. See [setting localisation options](tutorials/locales.md) tutorial. "en_GB.UTF-8" is the default language and I recommend leaving that enabled in any locale patch that you create.
2. The right hand side of <a name="prefer64BitKernel">`PREFER_64BIT_KERNEL`</a> to `true`. This only applies to 32-bit versions of Raspbian. Electing to run the 64-bit kernel gets some speed improvements and mostly works but, occasionally, you may strike a container that won't "play nice". For example:

	* [OctoPrint Docker](https://github.com/OctoPrint/octoprint-docker) seems to not like the 64-bit kernel but it is not clear whether the problem is the kernel, that I'm running it on a Raspberry Pi 3B+, or something intrinsic to the way the container is built.

	If you enable the 64-bit kernel by setting `PREFER_64BIT_KERNEL` to `true`, but you later decide to revert to the 32-bit kernel:

	```bash
	$ cd /boot
	$ sudo mv config.txt.bak config.txt
	$ sudo reboot
	```  

3. If you want the "supervised" version of Home Assistant to be installed, set the right hand side of `HOME_ASSISTANT_SUPERVISED_INSTALL` to `true`.

##### *on the subject of Home Assistant …*

You have the choice of:

1. The supervised installation (a set of Docker containers managed outside of IOTstack); or
2. A standalone `home_assistant` container selectable from the IOTstack menu.

You can't have both. The standalone container can be installed at any point in your IOTstack journey. Conversely, the supervised installation must be installed at system build time. You can't (easily) change your mind later so please make the decision now and choose wisely.

##### <a name="perHostConfigOptions"> per-host PiBuilder installation options </a>

The file:

```
~/PiBuilder/boot/scripts/support/pibuilder/options.sh
```

contains general options that will be used for **all** of your Raspberry Pis. If you want to create a set of options tailored to the needs of a particular Raspberry Pi, start by making a copy of the general file and append `@` followed by the host name to the copy. For example:

```bash
$ cd ~/PiBuilder/boot/scripts/support/pibuilder
$ cp options.sh options.sh@iot-hub
```

At run time, PiBuilder will give preference to an options file where the `@` suffix matches the name of the host.

#### <a name="configGit"> Git user configuration </a>

The file at the path:

```
~/PiBuilder/boot/scripts/support/home/pi/.gitconfig
```

is only a template. It contains:

```
[core]
	excludesfile = ~/.gitignore_global
	pager = less -r
[user]
	name = Your Name
	email = email@domain.com
	signingkey = 04B9CD3D381B574D
[pull]
	rebase = false
```

At the very least, you should:

1. Replace "Your Name"; and
2. Replace "email@domain.com"

If you have not created a key for signing commits, remove the `signingkey` line, otherwise set it to the correct value.

Hint:

* You may find it simpler to replace `.gitconfig` with whatever is in `.gitconfig` in your home directory on your support host.

You should only need to change `.gitconfig` in PiBuilder if you also change `.gitconfig` your home directory on your support host. Otherwise, the configuration can be re-used for all of your Raspberry Pis.

### <a name="setupPiBuilder"> Run the PiBuilder setup script </a>

Re-insert the media so the "boot" volume mounts. Run:

```bash
$ cd ~/PiBuilder
$ ./setup_boot_volume.sh «path-to-mount-point»
```

If your support platform is a Mac you can omit `«path-to-mount-point»` because it defaults to `/Volumes/boot`. 

I have tried to make this a generic script but I don't have the ability to test it on Windows. If the script does not work on your system, you can emulate it as follows:

1. Notice that the `~/PiBuilder/boot` folder contains three items:

	* a folder named `scripts`
	* a file named `ssh`
	* a file named `wpa_supplicant.conf`

2. Copy those three items from `~/PiBuilder/boot` to the top level of the `boot` volume.
3. Eject the media.

Note:

* Do not activate the 64-bit kernel at this stage. Defer this until your system is running.

### <a name="bootRPi"> Boot your Raspberry Pi </a>

Transfer the media to your Raspberry Pi and apply power.

A Raspberry Pi normally takes 20-30 seconds to boot. However, the first time you boot from a clean image it takes a bit longer (a minute or so). The longer boot time is explained by one-time setup code, such as generating host keys for SSH and expanding the root partition to fully occupy the available space on your media (SD or SSD). Be patient.

You will know your Raspberry Pi is ready when it starts responding to pings:

```bash
$ ping -c 1 raspberrypi.local
```

### <a name="runScripts"> Run the PiBuilder scripts in order </a>

#### <a name="runScript01"> Script 01 </a>

When your Raspberry Pi responds to pings, connect to it like this:

```bash
$ ssh-keygen -R raspberrypi.local
$ ssh -4 pi@raspberrypi.local
```

Notes:

* The `ssh-keygen` command is protective and removes any obsolete information from your "known hosts" file. Ignore any errors.
* The `-4` parameter on the `ssh` command instructs SSH to stick to IPv4.

Normally, SSH will issue a challenge like this:

```
The authenticity of host '«description»' can't be established.
ED25519 key fingerprint is SHA256:gobbledegook/gobbledegook.
Are you sure you want to continue connecting (yes/no)? 
```

This is sometimes referred to as <a name="tofudef">the TOFU (Trust On First Use) pattern</a>. Respond with:

```
yes
```

Your Raspberry Pi will ask for a password for the user `pi`. Respond with:

```
raspberry
```

Now it is time to run the first script. You need to decide on a name for your Raspberry Pi. The name "iot-hub" is used in this documentation but you should choose a name that makes sense to you. In choosing a name, you need to follow the rules for domain names:

* letters ("a".."z", "A".."Z") but all lower case is recommended
* digits ("0".."9")
* hyphen ("-") **not** underscore

Please don't use "raspberrypi". Always choose a **different** name that is unique on your network. Even if you only have a single Raspberry Pi, now, you have no idea what the future holds. You have only yourself to blame if you ever get into the situation where two or more Raspberry Pis are using the same name. It will confuse both you and your Raspberry Pis.

When you have chosen a name, substitute it for `iot-hub` in the following:

```bash
$ /boot/scripts/01_setup.sh iot-hub
```

The script will ask for a new password for the user "pi". The password you choose here replaces the default `raspberry` password.

> It will also become the password for VNC access but VNC is not enabled by default.

The characters you type are not echoed to the console so you will be prompted to enter the password twice:

```
New password for pi@iot-hub: 
Re-enter new password: 
```

The 01 script runs to completion and reboots your Raspberry Pi. Rebooting disconnects your SSH session, returning you to your support host.

Changing the name of your Raspberry Pi to something other than `raspberrypi` invalidates the associated SSH fingerprint that was set up earlier (the [TOFU pattern](#tofudef)). You should remove it from your "known hosts" file by typing:

```bash
$ ssh-keygen -R raspberrypi.local
```

#### <a name="runScript02"> Script 02 </a>

When your Raspberry Pi reboots, it will have the name "iot-hub" (or whatever name you chose). It should respond to:

* `iot-hub.local` – its multicast DNS name;
* `iot-hub.your.domain.com` – if you have done the necessary work with local DHCP and DNS servers;
* `iot-hub` – either implicitly because `.your.domain.com` is assumed and the above applies, or because you have added an entry to `/etc/hosts` on your support host; or 
* your Raspberry Pi's IP address(es) – one IP address per interface if both Ethernet and WiFi are active.

These instructions assume you will use the multicast DNS name but you can substitute the other forms if those make more sense in your environment. 

You will know your Raspberry Pi is ready when it starts responding to pings:

```bash
$ ping -c 1 iot-hub.local
```

Connect and login:

```bash
$ ssh-keygen -R iot-hub.local
$ ssh -4 pi@iot-hub.local
```

Note:

* The `ssh-keygen` is a protective command in case you had another host with the same name but a different fingerprint. Ignore any errors.

You can expect to see the [TOFU pattern](#tofudef) again. Respond with "yes". Then run:

```bash
$ /boot/scripts/02_setup.sh
```

The 02 script runs to completion and reboots your Raspberry Pi. It is quite a quick script so don't be surprised or think it hasn't done anything.

The 02 script also disables IPv6 so, from this point onwards, you can omit the `-4` parameter from SSH commands.

#### <a name="runScript03"> Script 03 </a>

Connect and login:

```bash
$ ssh pi@iot-hub.local
```

Run:

```bash
$ /boot/scripts/03_setup.sh
```

A common problem with this script is the error "Unable to connect to raspbian.raspberrypi.org". This seems to be transient but it also happens far more frequently than you would like or expect. The script attempts to work around this problem by processing each package individually, while keeping track of packages that could not be installed. Then, if there were any packages that could not be installed, the script:

- displays a list of the failed packages;
- invites you to try running the failed installations by hand; and
- asks you to re-run 03_setup.sh (which will skip over any packages that are already installed).

The 03 script ends with a logout (not a reboot) so you can login again immediately.

#### <a name="runScript04"> Script 04 </a>

Connect and login:

```bash
$ ssh pi@iot-hub.local
```

Whether Supervised Home Assistant is installed depends on two things:

* The value of the `HOME_ASSISTANT_SUPERVISED_INSTALL` variable set in your [configuration options](#configOptions); and
* The value of an **optional** argument that you can pass to the `04_setup.sh` script.

The table below explains the relationships:

`HOME_ASSISTANT_SUPERVISED_INSTALL`      | Command (argument is optional)    | HA Installed?
:---------------------------------------:|-----------------------------------|:-------------:
*undefined* **or** `false`               | `/boot/scripts/04_setup.sh`       | no
`true`                                   | `/boot/scripts/04_setup.sh`       | yes
*undefined* **or** `false` **or** `true` | `/boot/scripts/04_setup.sh false` | no
*undefined* **or** `false` **or** `true` | `/boot/scripts/04_setup.sh true`  | yes

In other words:

* if you do **not** pass an argument to the `04_setup.sh` script, Supervised Home Assistant will only be installed if `HOME_ASSISTANT_SUPERVISED_INSTALL=true`.
* if you **do** pass an argument to the `04_setup.sh` script, Supervised Home Assistant will only be installed if the value of that argument is the literal string `true`.

The optional argument gives you the ability to override the installation of Supervised Home Assistant without forcing you to edit the [configuration options](#configOptions) file if you forgot to set `HOME_ASSISTANT_SUPERVISED_INSTALL` before copying the PiBuilder files to your boot volume.

What you do next depends on whether you want to install Supervised Home Assistant:

* If you do **not** want to install Supervised Home Assistant, proceed to [install Docker only](#runScript04NoHA).
* If you **do** want to install Supervised Home Assistant, proceed to [install Docker + Home Assistant](#runScript04HA).

#### <a name="runScript04NoHA"> install Docker only </a>

This section assumes that you do **not** want to install Supervised Home Assistant. Run **ONE** of the following commands: 

1. This command assumes `HOME_ASSISTANT_SUPERVISED_INSTALL=false`:

	```bash
	$ /boot/scripts/04_setup.sh
	```

2. This command assumes `HOME_ASSISTANT_SUPERVISED_INSTALL=true` but you want to override it:

	```bash
	$ /boot/scripts/04_setup.sh false
	```

The 04 script installs Docker and ends with a reboot. Go to [Script 05](#runScript05).

#### <a name="runScript04HA"> install Docker + Home Assistant </a>

This section assumes that you **do** want to install Supervised Home Assistant.

> *The discussion below recommends that you connect your Raspberry Pi to Ethernet. I have installed Supervised Home Assistant, successfully, on a Raspberry Pi Zero W2. There is no Ethernet interface so, clearly, it works. A logical conclusion is that Supervised Home Assistant installer is now able to work around the problems that previously gave rise to the "use Ethernet" recommendation. What is unknown at this point is whether this new behaviour generalises to all Raspberry Pis. The Zero did hang but it was at the end of the 05 script. It's possible it was busy trying to get HA going and I was far too impatient. It came back OK after a power-cycle.* 

One of Supervised Home Assistant's dependencies is Network Manager. Network Manager makes serious changes to your operating system, with side-effects you may not expect such as giving your Raspberry Pi's WiFi interface a random MAC address.

> See [Why random MACs are such a hassle](https://sensorsiot.github.io/IOTstack/Containers/Home-Assistant/#why-random-macs-are-such-a-hassle) if you want a deeper understanding.

You are in for a world of pain if you do not understand what is going to happen and take appropriate precautions:

1. Make sure your Raspberry Pi is connected to Ethernet. This is only a temporary requirement. You can return to WiFi-only operation after Home Assistant is installed.
2. When the Ethernet interface initialises, work out its IP address:

	```bash
	$ ifconfig eth0

	eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
	        inet 192.168.132.9  netmask 255.255.255.0  broadcast 192.168.132.255
	        ether ab:cd:ef:12:34:56  txqueuelen 1000  (Ethernet)
	        RX packets 4166292  bytes 3545370373 (3.3 GiB)
	        RX errors 0  dropped 0  overruns 0  frame 0
	        TX packets 2086814  bytes 2024386593 (1.8 GiB)
	        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
	```

	In the above, the IP address assigned to the Ethernet interface is on the second line of output, to the right of "inet": 192.168.132.9.
3. Disconnect from your Raspberry Pi by pressing <kbd>control</kbd>+<kbd>d</kbd>.
4. Re-connect to your Raspberry Pi using its IP address. For example:

	```bash
	$ ssh pi@192.168.132.9
	``` 

	Connecting via IP address guarantees you are connected to your Raspberry Pi's Ethernet interface, whereas a multicast DNS address like `iot-hub.local` can connect to any available interface.

	If you are challenged with the [TOFU pattern](#tofudef), respond with "yes". 

5. Run **ONE** of the following commands:

	* This command assumes `HOME_ASSISTANT_SUPERVISED_INSTALL=true`:

		```bash
		$ /boot/scripts/04_setup.sh
		```

	* This command assumes `HOME_ASSISTANT_SUPERVISED_INSTALL=false` but you want to override it:

		```bash
		$ /boot/scripts/04_setup.sh true
		```

As well as installing Home Assistant and Docker, the 04 script:

* alters the default Network Manager configuration and turns off random WiFi MAC addresses; and
* reboots your Raspberry Pi.

#### <a name="runScript05"> Script 05 </a>

Once your Raspberry Pi comes back, login using:

```bash
$ ssh pi@iot-hub.local
```

Run:

```bash
$ /boot/scripts/05_setup.sh
```

That ends in a logout. Login again.

At this point, your Raspberry Pi is ready to run IOTstack. You can either restore a backup or go into the IOTstack menu and start choosing your containers:

```bash
$ cd ~/IOTstack
$ ./menu.sh
``` 

#### <a name="runScript06"> Script 06 (optional) </a>

This script is entirely optional. It rebuilds SQLite from source code. The version of SQLite you get from `apt install` doesn't have all the features you might expect if SQLite is your thing.

If you have no plans to run SQLite and/or don't need its more advanced features, just skip this step.

It is also OK to defer running this script until you have an actual need:

```bash
$ /boot/scripts/06_setup.sh
```  

## <a name="synopses"> Script summaries </a>

Every script has the same basic scaffolding:

* source the common functions from `/boot/scripts/support/pibuilder/functions.sh`
* invoke `run_pibuilder_prolog` which:
	- sources the [installation options](#configOptions) from either:

		- `/boot/scripts/support/pibuilder/options.sh@$HOSTNAME` or
		- `/boot/scripts/support/pibuilder/options.sh`

	- sources a script-specific user-defined prolog, if one exists
* perform the installation steps defined in the script
* invoke `run_pibuilder_epilog` which sources a script-specific user-defined epilog, if one exists
* either reboot your Raspberry Pi or logout, as is appropriate.

> When used in the context of shell scripts, the words "*source*", "*sourcing*" and "*sourced*" mean that the associated file is processed, inline, as though it were part of the original calling script. It is analogous to an "include" file.

### <a name="docScript01"> Script 01 </a>

The script:

* Assumes fresh install of Raspberry Pi OS.
* Snapshots `/etc` as `/etc-baseline` (a baseline reference).
* Initialises `~/.ssh` and `~/.gnupg` directories with correct permissions (700).
* If the operating system is Raspbian Buster, adds support for fetching `libseccomp2` as a backport (needed for Alpine-based Docker images).
* Runs full OS update/upgrade followed by an autoremove.
* Optionally replaces `/etc/ssh` with a preset.
* Sets the user password.
* Sets up VNC with the same password (but does NOT activate VNC)
* Optionally sets up locale(s).
* Optionally enables the 64-bit kernel (see [`PREFER_64BIT_KERNEL`](#prefer64BitKernel)).
* Sets raspi-config options:

	- boot to console
	- WiFi country code
	- TimeZone
	- Machine name

* Reboots

### <a name="docScript02"> Script 02 </a>

The script:

* Cleans up any leftovers from `/etc/ssh` replacement.
* Optionally sets up default language for your locale.
* Applies the recommended `allowinterfaces eth*,wlan*` patch.
* Applies [Does your Raspberry Pi's Wireless Interface freeze?](https://gist.github.com/Paraphraser/305f7c70e798a844d25293d496916e77). Only probes interfaces that are defined, are active, and obtain their IP addresses via DHCP.
* Optionally sets up local DNS.
* Disables IPv6
* Reboots

### <a name="docScript03"> Script 03 </a>

The script:

* If the operating system is Raspbian Buster, installs `libseccomp2` as a backport (needed for Alpine-based Docker images).
* Installs add-on packages (IOTstack dependencies and useful tools including crypto support).
* Makes Python3 the default.
* Optionally sets up Network Time Protocol sync with local time-servers. See [Configuring Raspbian to use local time-servers](https://gist.github.com/Paraphraser/e1129880015203c29f5e1376c6ca4a08).
* Installs any custom UDEV rules in `/etc/udev/rules.d`.
* Replaces `~/.profile`.
* Initialises crontab (scaffolding only; does nothing).
* Ensures `~/.local/bin` exists.
* Clones [SensorsIot/IOTstack](https://github.com/SensorsIot/IOTstack) to `~/IOTstack`.
* Clones [IOTstackAliases](https://github.com/Paraphraser/IOTstackAliases) to `~/.local/IOTstackAliases`.
* Installs `rclone` and `niet` packages (IOTstackBackup dependencies).
* Clones [IOTstackBackup](https://github.com/Paraphraser/IOTstackBackup) to `~/.local/IOTstackBackup` and installs scripts in `~/.local/bin`.
* Copies placeholder configuration files for `rclone` and IOTstackBackup into `~/.config`
* Ends with a logout.

### <a name="docScript04"> Script 04 </a>

The `HOME_ASSISTANT_SUPERVISED_INSTALL` variable is set in the [installation options](#configOptions).

* If `true` (or overridden to be `true`), the script:

	- Displays a hint to choose either "raspberrypi3" or "raspberrypi4" when prompted by the Home Assistant installation process.
	- Installs Home Assistant dependencies.
	- Installs Docker.
	- Installs the Home Assistant agent and package.
	- Turns off random WiFi MAC address generation imposed by NetworkManager.

* If `false' (or overridden to be `false`), the script only installs Docker.

The script then continues and:

* Sets up the `docker` and `bluetooth` group memberships assumed by IOTstack.
* Installs Docker-Compose.
* Installs the `ruamel.yaml` and `blessed` Python dependencies assumed by IOTstack.
* Appends `cgroup_memory=1 cgroup_enable=memory` to `/boot/cmdline.txt`. This change means that `docker stats` will report memory utilisation.
* Reboots.

### <a name="docScript05"> Script 05 </a>

The script:

* Sets up Git scaffolding (`.gitconfig` and `.gitignore_global`).
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
* Ends with a logout.

### <a name="docScript06">Script 06 (optional)</a>

This script is optional. It rebuilds SQLite from source code. The version you get from `apt install` doesn't have all the features you might want.

## <a name="scriptSearch"> How PiBuilder scripts search for files, folders and patches </a>

### <a name="searchForItem"> Search function – `supporting_file()` </a>

PiBuilder's search function is called `supporting_file()`. Despite the name, it can search for both files and folders.

`supporting_file()` takes a single argument which is always a path beginning with a `/`. In this context, the leading `/` means "the `support` directory".

On your support host (Mac/PC), the `support` directory is at the path:

```
~/PiBuilder/boot/scripts/support
```

When you [run the PiBuilder setup script](#setupPiBuilder), the `scripts` folder and its contents are copied to the `boot` partition. When the media is mounted on your Raspberry Pi, the absolute path to the `support` directory is:

```
/boot/scripts/support
```

That path is the starting point for all searching. Suppose a script invokes:

```bash
$ supporting_file "/etc/resolv.conf"
```

The `supporting_file()` function first prepends the absolute path to the support directory on your Raspberry Pi, which results in:

```
/boot/scripts/support/etc/resolv.conf
```

That path is considered the *general* path.

The `supporting_file()` function also prepares a *host-specific* path by appending `@` plus the `$HOSTNAME` environment variable. For example:

```
/boot/scripts/support/etc/resolv.conf@iot-hub
```

If the *host-specific* path exists, the *general* path is ignored. The *general* path is only used if the *host-specific* path does not exist.

If whichever path emerges from the preceding step:

* is a file of non-zero length; **or**
* is a folder containing at least one visible component (file or sub-folder),

then `supporting_file()` returns that path and sets its result code to mean that the path can be used. Otherwise the result code is set to mean that no path was found.

In most cases, `supporting_file()` is used like this:

```bash
TARGET="/etc/resolv.conf"
if SOURCE="$(supporting_file "$TARGET")" ; then
   
   # do something like copy $SOURCE to $TARGET

fi
``` 

### <a name="searchForPatch"> Patch function – `try_patch()` </a>

The `try_patch()` function takes two arguments:

1. A path beginning with a `/` where the `/` means "the `support` directory".
2. A comment string summarising the purpose of the patch.

For example:

```bash
try_patch "/etc/resolv.conf" "this is an example"
```

The patch algorithm appends `.patch` to the path supplied in the first argument and then invokes `supporting_file()`:

```bash
supporting_file "/etc/resolv.conf.patch"
``` 

Calling `supporting_file()` implies two candidates will be considered:

```
/boot/scripts/support/etc/resolv.conf.patch@iot-hub
/boot/scripts/support/etc/resolv.conf.patch
``` 

The *host-specific* form is given precedence over the *general* form.

If `supporting_file()` returns a candidate, the patching algorithm will assume it is a valid patch file and attempt to apply it to the target file. It sets its result code to mean "success" if and only if the patch was applied.

The `try_patch()` function has two common use patterns:

* unconditional invocation where there are no actions that depend on the success of the patch. For example:

	```bash
	try_patch "/etc/dhcpcd.conf" "allowinterfaces eth*,wlan*"
	``` 

* conditional invocation where subsequent actions depend on the success of the patch. For example:

	```bash
	if try_patch "/etc/locale.gen" "setting locales (ignore errors)" ; then
		sudo dpkg-reconfigure -f noninteractive locales
	fi
	```

## <a name="patchPreparation"> Preparing your own patches </a>

PiBuilder can *apply* patches for you, but you still need to *create* each patch.

### <a name="patchTools"> Tools overview: *diff* and *patch* </a>

Understanding how patching works will help you to develop and test patches before handing them to PiBuilder. Assume:

1. an «original» file (the original supplied as part of Raspbian); and
2. a «final» file (after your editing to make configuration changes).

To create a «patch» file, you use the `diff` tool which is part of Unix:

```bash
$ diff «original» «final» > «patch»
```

Subsequently, given:

1. a fresh Raspbian install where only «original» exists; plus
2. your «patch» file,

you use the `patch` tool which is also part of Unix:

```bash
$ patch -bfnz.bak -i «patch» «original»
```

That `patch` command will:

1. copy «original» to «original».bak; and
2. apply «patch» to «original» to convert it to «final».

### <a name="patchSummary"> Basic process </a>

The basic process for creating a patch file for use in PiBuilder is:

1. Make sure you have a baseline version of the file you want to change. The baseline version of a «target» file should always be whatever was in the Raspbian image you downloaded from the web. Typically, there are two situations:

	* You have run PiBuilder and PiBuilder has already applied a patch to the «target» file. In that case, `«target».bak` is a copy of whatever was in the Raspbian image you downloaded from the web. That means `«target».bak` is your baseline and you don't need to do anything else.
	* The «target» file has never been changed. The currently-active file is your baseline so you need to preserve it by making a copy before you start changing anything. The most likely place where you will be working is the `/etc` directory so `sudo` is usually appropriate:

		```bash
		$ sudo cp «target» «target».bak
		```

	Note:

	* One of PiBuilder's first actions in the 01 script is to make a copy of `/etc` as `/etc-baseline`. PiBuilder does this before it makes any changes. If you make some changes in the `/etc` directory and only then realise that you forgot to save a baseline copy, you can always fetch a copy of the original file from `/etc-baseline`. 

2. Make whatever changes you need to make to the «target». Sometimes this will involve using `sudo` and a text editor. Other times, you will be able to run a configuration tool like `raspi-config` and it will change the «target» file(s) for you.
3. Create a «patch» file using the `diff` tool. For any given patch file, you always have two options:

	* If the patch file should apply to a **specific** Raspberry Pi, generate the patch file like this:

		```bash
		$ diff «target».bak «target» > «target».patch@$HOSTNAME
		```

	* If the patch file should apply to **all** of your Raspberry Pis each time they are built, generate the patch file like this:

		```bash
		$ diff «target».bak «target» > «target».patch
		```

	You can do both. A *host-specific* patch always takes precedence over a *general* patch.

4. Place the «patch» file in its proper location in the PiBuilder structure on your support host.

	For example, suppose you have prepared a patch that will be applied to the following file on your Raspberry Pi:

	```
	/etc/resolvconf.conf
	```

	Remove the file name, leaving the path component:

	```
	/etc
	```

	The path to the support folder in your PiBuilder structure on your support host is:

	```
	~/PiBuilder/boot/scripts/support
	```

	Append the path component ("`/etc`") to the path to the support folder:

	```
	~/PiBuilder/boot/scripts/support/etc
	```

	That folder is where your patch files should be placed. The patch file you prepared will have one of the following names:

	```
	resolvconf.conf.patch@iot-hub
	resolvconf.conf.patch
	```

	The proper location for the patch file in the PiBuilder structure structure on your support host is one of the following paths:

	```
	~/PiBuilder/boot/scripts/support/etc/resolvconf.conf.patch@iot-hub
	~/PiBuilder/boot/scripts/support/etc/resolvconf.conf.patch
	```

### <a name="patchTutorials"> Tutorials </a>

PiBuilder already has "hooks" in place for some common situations. All you need to do is prepare a patch file and PiBuilder will apply it the next time you build an operating system:

* [Setting localisation options](tutorials/locales.md)
* [Setting Domain Name System servers](tutorials/dns.md)
* [Setting your closest Network Time Protocol servers](tutorials/ntp.md)
* [Setting up static IP addresses for your Raspberry Pi](tutorials/ip.md)

The next tutorial covers a situation where PiBuilder does not have a "hook". It explains how to prepare the patches, how to add them to your PiBuilder structure, and how to hook the patches into the PiBuilder process using a script epilog:

* [Restoring Buster-style log rotation for syslog](tutorials/logrotate.md)

## <a name="moreGit"> Keeping in sync with GitHub </a>

The instructions in [download this repository](#downloadRepo) recommended that you create a Git branch ("custom") to hold your customisations. If you did not do that, please do so now:

```bash
$ cd ~/PiBuilder
$ git checkout -b custom
```

Notes:

* any changes you may have made *before* creating the "custom" branch will become part of the "custom" branch. You won't lose anything. After you "add" and "commit" your changes on the "custom" branch, the "master" branch will be a faithful copy of the PiBuilder repository on GitHub at the moment you first cloned it.
* once the "custom" branch becomes your working branch, there should be no need to switch branches inside the PiBuilder repository. The instructions in this section assume you are always in the "custom" branch.

From time to time as you make changes, you should run:

```bash
$ git status
```

Add any new or modified files or folders using:

```bash
$ git add «path»
```

Note:

* You can't add an empty folder to a Git repository. A folder must contain at least one file before Git will consider it for inclusion.

Whenever you reach a logical milestone, commit your changes:

```bash
$ get commit -m "added a patch for something or other"
```

> naturally, you will want to use a far more informative commit message!

Periodically, you will want to check for updates to PiBuilder on GitHub:

```bash
$ git fetch origin master:master
```

That pulls changes into the master branch. Next, you will want to merge those changes into your "custom" branch:

```bash
$ git merge master --no-commit
```

If the merge:

* succeeds, you will see:

	```
	Automatic merge went well; stopped before committing as requested
	```

* is blocked before it completes, you will see one or more messages like this:

	```
	CONFLICT (content): Merge conflict in «filename»
	```

	That tells you that the problem is in «filename». For each file mentioned in such a message:

	1. Open the file using your favourite text editor.
	2. Search for `<<<<<<<`. You are looking for a pattern like this:

		```
		<<<<<<< HEAD
		one or more lines of your own text
		=======
		one or more lines of text coming from PiBuilder on GitHub
		>>>>>>> master
		```

	3. To resolve the conflict, you just need to decide what the file should look like and remove the conflict markers:

		* If you want to preserve your own text and discard the PiBuilder lines, reduce the above to just:

			```
			one or more lines of your own text
			```

		* If you want the lines coming from the PiBuilder to replace your own, reduce the above to just:

			```
			one or more lines of text coming from PiBuilder on GitHub
			```

		* If you want to preserve material from both:

			```
			one or more lines of your own text
			one or more lines of text coming from PiBuilder on GitHub
			```

			or:

			```
			one or more lines of my own text merged with one or more lines from GitHub
			```

	4.	Don't forget that a file may have more than one area of conflict so go back to step 2 and repeat the search until you are sure all the conflicts have been found and resolved.
	5. Once you are sure you have resolved all of the conflicts in a file, tell `git` by:

		```bash
		$ git add «filename»
		```

	5. If more than one file was marked as being in conflict, start over from step 1. You can always refresh your memory on which files are still in conflict by:

		```bash
		$ git status

		…
		Changes to be committed:
			modified:   file1.txt

		Unmerged paths:
			both modified:   file2.txt
		…
		```

		In the above, `file1.txt` is no longer in conflict but `file2.txt` still needs to be checked.

It does not matter whether the merge succeeded immediately or if it was blocked and you had to resolve conflicts, the next step is to run:

```bash
$ git status
``` 

For each file mentioned in the status list that is not in the "Changes to be committed" list, run:

```bash
$ git add «filename»
```

The last step is to commit the merged changes to your own branch:

```bash
$ git commit -m "merged with GitHub updates"
```

Now you are in sync with GitHub.

## <a name="chickenEgg"> Beware of chickens and eggs </a>

Installing and configuring software on a Raspberry Pi (or any computer) involves quite a few chicken-and-egg situations. For example:

* Until you decide to install [IOTstackBackup](https://github.com/Paraphraser/IOTstackBackup), you:

	- May not have had a need to install `rclone`
	- May not have had to configure `rclone` to use Dropbox as a remote
	- Will not have had to think about configuring `iotstack_backup`.

* If you decide to install IOTstackBackup then you will need to think about all those things.
* Once you have obtained an "app key" for Dropbox, have established an `rclone` remote to talk to Dropbox, and have configured IOTstackBackup to use that remote, you will expect to be able to take backups, and then restore those backups on your Raspberry Pi. And you will!
* … until you rebuild your Raspberry Pi. To be able to restore after a rebuild, you **must** have the `rclone` and `iotstack_backup` configurations in place. You either need to:

	- recreate those by hand (and obtain a new Dropbox app key), or
	- recover them from somewhere else (eg another Raspberry Pi) or, *best of all*
	- make sure they are in the right place for PiBuilder to be able to copy them into place automatically at the right time.

* This repo assumes the last option: you have saved the `rclone` and `iotstack_backup` configuration files into the proper location in the `support` directory:

	```
	~/PiBuilder/boot/scripts/support/home/pi/.config/
	├── iotstack_backup
	│   └── config.yml
	└── rclone
	    └── rclone.conf
	```

* Of course, in order to have saved those configurations into the proper location, you will first have had to have set them up and tested them.

Chicken-and-egg!

There is no substitute for thinking, planning and testing.

## <a name="aboutSSH"> Some words about SSH </a>

### <a name="aboutEtcSSH"> About `/etc/ssh` </a>

Whenever you start from a clean Raspberry Pi OS image, the very first boot-up initialises:

```
/etc/ssh
```

The contents of that folder can be thought of as a unique identity for the SSH service on your Raspberry Pi. That "identity" can be captured by: 

```bash
$ cd
$ /boot/scripts/helpers/etc_ssh_backup.sh
```

Suppose your Raspberry Pi has the name "iot-hub". The result of running that script will be:

```
~/etc-ssh-backup.tar.gz@iot-hub
```

If you copy that file into your PiBuilder folder at path:

```
~/PiBuilder/boot/scripts/support/etc/ssh/
```

and then run `setup_boot_volume.sh`, the `etc-ssh-backup.tar.gz@iot-hub` will be copied onto the `boot` volume along with everything else.

When you boot your Raspberry Pi and run:

```bash
$ /boot/scripts/01_setup.sh iot-hub
``` 

the script will search for `etc-ssh-backup.tar.gz@iot-hub` and, if found, will use it to restore `/etc/ssh` as it was at the time the snapshot was taken. In effect, you have given the machine its original SSH identity.

The contents of `/etc/ssh` are not tied to the physical hardware so if, for example, your "live" Raspberry Pi emits magic smoke and you have to repurpose your "test" Raspberry Pi, you can cause the replacement to take on the SSH identity of the failed hardware.

> Fairly obviously, you will still need to do things like change your DHCP server so that the working hardware gets the IP address(es) of the failed hardware, but the SSH side of things will be in place.

Whether you do this for any or all of your hosts is entirely up to you. I have gone to the trouble of setting up SSH certificates and it is a real pain to have to run around and re-sign the host keys every time I rebuild a Raspberry Pi. It is much easier to set up `/etc/ssh` **once**, then take a snapshot, and re-use the snapshot each time I rebuild.

The *practical* effect of this is that my build sequence begins with:

```bash
$ ssh pi@raspberrypi.local
raspberry
$ /boot/scripts/01_setup.sh previousname
$ ssh-keygen -R raspberrypi.local
$ ssh previousname
…
```

No `pi@` on the front. No `.local` or domain name on the end. No [TOFU pattern](#tofudef). No password prompt. Just logged-in.

If you want to learn how to set up password-less SSH access, see [IOTstackBackup SSH tutorial](https://github.com/Paraphraser/IOTstackBackup/blob/master/ssh_tutorial.md). Google is your friend if you want to go the next step and set up SSH certificates.

### <a name="aboutDotSSH"> About `~/.ssh` </a>

The contents of `~/.ssh` carry the client identity (how "pi" authenticates to target hosts), as distinct from the machine identity (how your Raspberry Pi proves itself to clients seeking to connect).

Personally, I use a different approach to maintain and manage `~/.ssh` but it is still perfectly valid to run the supplied:

```bash
$ /boot/scripts/helpers/user_ssh_backup.sh
``` 

and then restore the snapshot in the same way as Script 01 does for `/etc/ssh`. I haven't provided a solution in PiBuilder. You will have to come up with that for yourself.

### <a name="snapshotSecurity"> Security of snapshots </a>

There is an assumption that it is "hard" for an unauthorised person to gain access to `etc/ssh` and, to a lesser extent, `~/.ssh`. How "hard" that actually is depends on a lot of things, not the least of which is whether you are in the habit of leaving terminal sessions unattended...

Nevertheless, it is important to be aware that the snapshots do contain sufficient information to allow a third party to impersonate your hosts so it is probably worthwhile making some attempt to keep them reasonably secure.

I keep my snapshots on an encrypted volume. You may wish to do the same.

## <a name="changeLog"> Change Summary </a>

* 2021-12-29

	- Improve documentation on OS versions tested with PiBuilder and how to choose between them.
	- Add instructions for checking SHA256 signatures.
	- Split `options.sh` instructions into "should" and "can" categories.
	- Document `cmdline.txt` and `config.txt` script changes made yesterday.
	- Rewrite some sections of DNS tutorial.
	- Fix typos etc.
	- Change summary to the end of the readme.

* 2021-12-28

	- Rename `is_running_raspbian()` function to `is_running_OS_release()`. The full 64-bit OS identifies as "Debian". That part of the test removed as unnecessary.
	- Add `is_running_OS_64bit()` function to return true if a full 64-bit OS is running.
	- Install 64-bit `docker-compose` where appropriate.
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

