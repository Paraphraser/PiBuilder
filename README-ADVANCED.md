# Advanced PiBuilder

This document explains how to customise PiBuilder to your needs.

<a name="toc"></a>
## Contents

- [Overview](#overview)

- [Getting started](#gettingStarted)

- [PiBuilder installation options](#generalOptions)

	- [Per-host installation options](#hostSpecificOptions)
	- [Environment variable overrides](#envVarOverrides)

		- [about Git options](#aboutGitOptions)

- [Script scaffolding](#scriptScaffolding)

- [The PiBuilder Patching System](#patchingSystem)

	- [How PiBuilder scripts search for files, folders and patches](#scriptSearch)

		- [Search function](#supportingFileFunction)
		- [Patch function](#tryPatchFunction)
		- [Folder merge function](#tryMergeFunction)

	- [Preparing your own patches](#patchPreparation)

		- [Tools overview: *diff* and *patch*](#patchTools)
		- [Basic process](#patchSummary)

	- [Configure home directory](#configHome)

		- [`.bashrc`](#configBashrc)
		- [`.config/iotstack_backup/config.yml`](#configBackupCfg)
		- [`.config/rclone/rclone.conf`](#configRcloneCfg)
		- [`.gitconfig`](#configGit)
		- [`.gitignore_global`](#configGitIgnore)
		- [`crontab`](#crontab)

- [Existing customisation points](#patchPoints)

	- [DHCP client daemon](#etc_dhcpcd_conf)
	- [Docker daemon](#etc_docker_daemon)
	- [System swap-file](#etc_dphys_swapfile)
	- [GRUB](#etc_defaults_grub)
	- [Locales](#etc_locales)
	- [Network interfaces](#etc_network)
	- [Network interface monitoring](#etc_rc_local)
	- [DNS resolver](#etc_resolvconf_conf)
	- [Samba (SMB)](#etc_samba_smb_conf)
	- [Secure Shell (SSH)](#etc_ssh)
	- [Kernel parameters](#etc_sysctl_d)
	- [Journal control](#etc_systemd_journald_conf)
	- [Time synchronisation](#etc_systemd_timesyncd_conf)
	- [Dynamic device management (UDEV)](#etc_udev_rules_d)

- [Using your custom branch in a build](#customBuild)

	- [Original build method still works](#originalBuild)

- [Keeping in sync with GitHub](#githubSync)

<a name="overview"></a>
## Overview

PiBuilder's main goal is to tailor a Raspberry Pi OS system to support IOTstack. If you are a first-time user, running the PiBuilder scripts and (implicitly) accepting all defaults will get you a stable "server" platform optimised for running your Docker containers.

As time goes on and you make changes to your Raspberry Pi, you may find yourself wondering what would happen if your Raspberry Pi failed (corrupted SD card; magic smoke; operator error) and you needed to rebuild it.

Here's an example of the kind of problem you might encounter. PiBuilder installs [IOTstackBackup](https://github.com/Paraphraser/IOTstackBackup). Suppose you decide to take advantage of that. You follow the IOTstackBackup [README](https://github.com/Paraphraser/IOTstackBackup/blob/master/README.md). You choose the RCLONE option and set up a connection with Dropbox so your backups are saved in the cloud. And you finish off by creating a cron job to run `iotstack_backup` once a day.

If you ever have to rebuild your Raspberry Pi from scratch, PiBuilder will still install IOTstackBackup but you won't be able to run `iotstack_restore` to restore your IOTstack as of the last backup. Two other components are required:

1. Your RCLONE configuration. This contains your Dropbox token and is stored in `~/.config/rclone`.
2. Your IOTstackBackup configuration. That tells IOTstackBackup to use RCLONE and Dropbox for backup and restore operations. It is stored in `~/.config/iotstack_backup`.

It's actually a chicken-and-egg problem. Those files aren't included in any backup and, even if they were, that wouldn't help because you would still need the configuration files to be in the right place on your Raspberry Pi *before* you could fetch the backup files and extract the configuration files.

The solution is to add the [IOTstackBackup](#configBackupCfg) and [RCLONE](#configRcloneCfg) configurations to PiBuilder. Then, the configuration files will already be in the right place at the end of the PiBuilder run and you will be able to run `iotstack_restore` without further ado.

Adding those configuration files to PiBuilder also means you won't have to go through the IOTstackBackup setup procedure on the newly-rebuilt Raspberry Pi before you can run `iotstack_backup`. Sort of win, win, win.

Customising PiBuilder doesn't just help with IOTstackBackup configuration files. You can include add your own packages to be installed via `apt`. Custom configuration files in `/etc`. Whatever you want, really.

<a name="gettingStarted"></a>
## Getting started

The examples here assume you will be working at the command line but you can also use desktop tools.

Start by cloning PiBuilder onto your support host: 

``` bash
$ git clone https://github.com/Paraphraser/PiBuilder.git ~/PiBuilder
```

> PiBuilder does not have to be located in your home directory. It can be anywhere. Just substitute the appropriate path wherever you see `~/PiBuilder`.

Create a custom branch to keep your own changes separate from the main repository on GitHub. A custom branch makes it a bit simpler to manage merging if a change you make conflicts with a change coming from GitHub.

``` bash
$ cd ~/PiBuilder
$ git switch -c custom
```

> You don't have to call your branch "custom". You can choose any name you like.

<a name="generalOptions"></a>
## PiBuilder installation options

Use a text editor to open:

```
~/PiBuilder/boot/scripts/support/pibuilder/options.sh
```

The file supplied with PiBuilder looks like this:

``` bash
 # this file is "sourced" in all build scripts. In the release version,
 # all variables are commented-out and shown with their default values.

 # - skip full upgrade in the 01 script.
 #SKIP_FULL_UPGRADE=false

 # - skip firmware in the 01 script.
 #SKIP_EEPROM_UPGRADE=false

 # - preference for kernel. Only applies to 32-bit installations. If
 #   true, adds "arm_64bit=1" to /boot/config.txt
 #PREFER_64BIT_KERNEL=false

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
```

The defaults are appropriate for most first-time builds. However, you can uncomment any variable and set its right hand side as follows:

* <a name="skipFullUpgrade"></a>`SKIP_FULL_UPGRADE` to `true`. This prevents the 01 script from performing a "full upgrade". It may be appropriate if you want to test against a base release of Raspberry Pi OS.
* <a name="skipFirmwareUpgrade"></a>`SKIP_EEPROM_UPGRADE` to `true`. This prevents the 01 script from updating your Raspberry Pi's firmware. Otherwise, the 01 script runs:

	``` bash
	$ rpi-eeprom-update
	```

	If and only if the response includes "UPDATE AVAILABLE" is a firmware update applied. The EEPROM is updated during the reboot at the end of the 01 script. The process adds extra time to the normal reboot cycle so please be patient. 

* <a name="prefer64BitKernel"></a>`PREFER_64BIT_KERNEL` to `true`. This only applies to 32-bit versions of Raspbian. The overall effect is a 64-bit kernel with a 32-bit user mode.
* <a name="handleVMswap"></a>`VM_SWAP` to:

	- `disable` to disable virtual memory (VM) swapping. This is appropriate if your Raspberry Pi boots from SD **and** has limited RAM.
	- `automatic`:

		- If the Pi is running from an SD card, this is the same as `disable`.
		- If the Pi is not running from an SD card, the script changes the swap configuration in `/etc/dphys-swapfile` so that swap size is calculated in two steps:

			1. The amount of real RAM is doubled (eg a 2GB Raspberry Pi 4 will be doubled to 4GB);
			2. A maximum limit of 2GB is applied.

			This calculation will result in a 2GB swap file for any Raspberry Pi with 1GB or more of real RAM. This is the recommended option if your Raspberry Pi boots from SSD or HD.

			Rules 1 and 2 are implemented by the `./etc/dphys-swapfile.patch` supplied with PiBuilder. If you change or override that file then whatever rules your patch imposes will be implemented by `automatic`.

	- `custom` is equivalent to `automatic` but it does not check if your system is running from SD. If you want to enable swap on an SD system, this or "default" are the options to use.

	- `default` makes no changes to the virtual memory system. The current Raspberry Pi OS defaults enable virtual memory swapping with a swap file size of 100MB. This is perfectly workable on systems with 4GB of RAM or more.

	If `VM_SWAP` is not set, it defaults to `automatic`.

	Running out of RAM causes swapping to occur and that, in turn, has both a performance penalty (because SD cards are quite slow) and increases the wear and tear on the SD card (leading to a heightened risk of failure). There are two main causes of limited RAM:

	- Insufficient physical memory. A good example is a Raspberry Pi Zero W2 which only has 512MB to start with; and/or
	- Expecting your Raspberry Pi to do too much work, such as running a significant number of containers which either have large memory footprints, or cause a lot of I/O and consume cache buffers, or both.

	If you disable VM swapping by setting `VM_SWAP` to `disable`, but you later decide to re-enable swapping, run these commands:

	``` bash
	$ sudo systemctl enable dphys-swapfile.service
	$ sudo reboot
	```

	You can always check if swapping is enabled using the `swapon -s` command. Silence means swapping is disabled.

	VM swapping is not **bad**. Please don't disable swapping without giving it some thought. If you can afford to add an SSD, you'll get a better result with swapping enabled than if you stick with the SD and disable swapping.

* `LOCALE_LANG` to a valid language descriptor but any value you set here **must** also be enabled via a locale patch. See [setting localisation options](./docs/locales.md) tutorial. "en_GB.UTF-8" is the default language and I recommend leaving that enabled in any locale patch that you create.
* <a name="enablePiCam"></a>`ENABLE_PI_CAMERA` controls whether the Raspberry Pi ribbon-cable camera support is enabled at boot time:

	- `false` (or undefined) means "do not attempt to enable the camera".
	- `true` means "enable the camera in the mode that is native for the version of Raspberry Pi OS that is running".
	- `legacy`, if the Raspberry Pi is running:
		- *Buster*, then `legacy` is identical to `true`;
		- *Bullseye* the legacy camera system is loaded rather than the native version. In other words, Bullseye's camera system behaves like Buster and earlier. This is the setting to use if downstream applications have not been updated to use Bullseye's native camera system. 

* <a name="dotLoginAction"></a>`DOT_BASHRC_ACTION` and `DOT_PROFILE_ACTION` both default to `append`. Allowable values if uncommented are `append`, `replace` and `skip`. See [Login Profiles](./docs/login.md) tutorial for more information on how to use these options.

<a name="hostSpecificOptions"></a>
### Per-host installation options

Changes you make to the following file apply to **all** your hosts:

```
~/PiBuilder/boot/scripts/support/pibuilder/options.sh
```

You can also create a variant of the options file which is specific to a given host. You do that by appending `@` followed by the host name. For example, if your Raspberry Pi uses the name "iot-hub", its host-specific options file would be:

```
~/PiBuilder/boot/scripts/support/pibuilder/options.sh@iot-hub
```

If both a host-specific and a general options file exist, the host-specific file is given precedence and the general file is ignored. 

<a name="envVarOverrides"></a>
### Environment variable overrides

Some of PiBuilder's scripts support additional customisation by setting environment variables that are not listed in the default `options.sh`. You can apply overrides in one of three ways:

1. Adding the environment variable to your `options.sh`; or
2. Specifying the override inline on the call to the script. For example:

	``` console
	$ IOTSTACK="$HOME/MySpecialIOTstack" ./PiBuilder/boot/scripts/03_setup.sh
	```

3. Exporting the override before calling the script. Example:

	``` console
	$ export IOTSTACK="$HOME/MySpecialIOTstack"
	$ ./PiBuilder/boot/scripts/03_setup.sh
	```

The variables supported in this fashion are summarised below.

variable                 | script(s) | default
-------------------------|:---------:|------------------------------------------
`GIT_CLONE_OPTIONS`      | 03        | `--filter=tree:0`
`IOTSTACK`               | 03, 04    | `$HOME/IOTstack`
`IOTSTACK_URL`           | 03        | `https://github.com/SensorsIot/IOTstack.git`
`IOTSTACK_BRANCH`        | 03        | `master`
`IOTSTACKALIASES_URL`    | 03        | `https://github.com/Paraphraser/IOTstackAliases.git`
`IOTSTACKALIASES_BRANCH` | 03        | `master`
`IOTSTACKBACKUP_URL`     | 03        | `https://github.com/Paraphraser/IOTstackBackup.git`
`IOTSTACKBACKUP_BRANCH`  | 03        | `master`

The variables with `_URL` and `_BRANCH` suffixes are intended to make it easy to clone those repositories from your own custom clones, forks and branches.

Note:

* If you change the `IOTSTACK` variable, you must be consistent and use it for both the 03 and 04 scripts, otherwise PiBuilder will raise an error.

<a name="aboutGitOptions"></a>
#### about Git options

The default value of `GIT_CLONE_OPTIONS` is consistent with the IOTstack `install.sh` script, save that it is also applied to cloning the IOTstackAliases and IOTstackBackup repositories.

These are your options for invoking the 03 script. They are ranked in increasing order of the load placed on GitHub:

* *Shallow* clone (least expensive):

	``` console
	$ GIT_CLONE_OPTIONS="--depth=1" ./PiBuilder/boot/scripts/03_setup.sh
	```
	
	This is the "cheapest" download but it constrains your options (eg your ability to switch between the IOTstack *old* and *new* menu systems) quite severely. Not really recommended.

* *Treeless* clone (the PiBuilder default):

	``` console
	$ ./PiBuilder/boot/scripts/03_setup.sh
	```
	
	This passes the `--filter=tree:0` option to `git clone`. It only downloads from GitHub what is essential to running IOTstack on your machine. The downloading of additional components is deferred until it is actually necessary which, in many installations, could easily be "never".
	
* *Blobless* clone:

	``` console
	$ GIT_CLONE_OPTIONS="--filter=blob:none" ./PiBuilder/boot/scripts/03_setup.sh
	```
	
	This download all reachable commits and trees, but only downloads blobs when necessary.

* *Full* clone (most expensive):

	``` console
	$ GIT_CLONE_OPTIONS= ./PiBuilder/boot/scripts/03_setup.sh
	```

	This is the more traditional clone which downloads a complete copy of each repository from GitHub. 

Note:

* You can use `GIT_CLONE_OPTIONS=` to pass any supported options to the `git clone` command. Fairly obviously, you are responsible for passing *valid* options!

See also:
	
- [IOTstack PR740](https://github.com/SensorsIot/IOTstack/pull/740)
- [Get up to speed with partial clones](https://github.blog/2020-12-21-get-up-to-speed-with-partial-clone-and-shallow-clone/)
	
<a name="scriptScaffolding"></a>
## Script scaffolding

Every script has the same basic scaffolding:

* source the common functions from `functions.sh`
* invoke `run_pibuilder_prolog` which:

	- sources the [installation options](#generalOptions) from either:

		- `options.sh@$HOSTNAME` or
		- `options.sh`

	- sources a script-specific user-defined prolog, if one exists

* perform the installation steps defined in the script
* invoke `run_pibuilder_epilog` which sources a script-specific user-defined epilog, if one exists
* either reboot your Raspberry Pi or logout, as is appropriate.

Note:

* When used in the context of shell scripts, the words "*source*", "*sourcing*" and "*sourced*" mean that the associated file is processed, inline, as though it were part of the original calling script. It is analogous to an "include" file.

<a name="patchingSystem"></a>
## The PiBuilder Patching System

<a name="scriptSearch"></a>
### How PiBuilder scripts search for files, folders and patches

<a name="supportingFileFunction"></a>
#### Search function

PiBuilder's search function is called `supporting_file()`. Despite the name, it can search for both files and folders.

In most cases, `supporting_file()` is used like this:

``` bash
TARGET="/etc/resolv.conf"
if SOURCE="$(supporting_file "$TARGET")" ; then
   
   # do something like copy $SOURCE to $TARGET

fi
```

Here's a walkthrough. `supporting_file()` takes a single argument which is always a path beginning with a `/`. The path to the `support` directory is prepended so the argument so you wind up with an absolute path like this:

```
/home/pi/PiBuilder/boot/scripts/support/etc/resolv.conf
```

That path is considered to be the *general* path. A *host-specific* is constructed from the *general* path by appending `@` plus the `$HOSTNAME` environment variable. For example, if `HOSTNAME` had the value "iot-hub" the *host-specific* path would be:

```
/home/pi/PiBuilder/boot/scripts/support/etc/resolv.conf@iot-hub
```

If the *host-specific* path exists, the *general* path is ignored. The *general* path is only used if the *host-specific* path does not exist.

If whichever path emerges from the preceding step is:

* a file of non-zero length; or
* a folder containing at least one **visible** component (file or sub-folder),

then `supporting_file()` returns that path and sets its result code to mean that the path can be used. Otherwise the result code is set to mean that no path was found.

So, assuming the `if` test succeeds:

* `SOURCE` will be the absolute path inside the PiBuilder folder to either a *host-specific* or *general* path containing your customisations; and
* `TARGET` will be an absolute path on the Raspberry Pi to the file to be replaced or otherwise manipulated.

If the conditional code within the scope of the `if` were, say:

```
cp "$SOURCE" "$TARGET"
```

the effect would be to replace the default version of `resolv.conf` supplied with your Raspberry Pi, with the version provided by you in PiBuilder.

<a name="tryPatchFunction"></a>
#### Patch function

The `try_patch()` function takes two or three arguments:

1. A path beginning with a `/` which has the same definition as for [`supporting_file()`](#supportingFileFunction).
2. A comment string summarising the purpose of the patch.
3. An optional boolean. If "true", it instructs the function to ignore patching errors. Defaults to false if omitted. 

For example:

``` bash
try_patch "/etc/resolv.conf" "this is an example"
```

The patch algorithm appends `.patch` to the path supplied in the first argument and then invokes `supporting_file()`:

``` bash
supporting_file "/etc/resolv.conf.patch"
``` 

Calling `supporting_file()` implies both *host-specific* and *general* candidates will be considered, with the *host-specific* form given precedence.

If `supporting_file()` returns a candidate, the patching algorithm will assume it is a valid patch file and attempt to apply it to the target file. The function sets its result code to mean "success" if either:

* the patch was applied successfully; or
* the patch failed, in whole or in part, and the third argument is true.

Otherwise the function result code is set to mean "fail".

The `try_patch()` function has two common use patterns:

* unconditional invocation where there are no actions that depend on the success of the patch. For example:

	``` bash
	try_patch "/etc/dhcpcd.conf" "allowinterfaces eth*,wlan*"
	``` 

* conditional invocation where subsequent actions depend on the success of the patch. For example:

	``` bash
	if try_patch "/etc/dphys-swapfile" "setting swap to max(2*physRAM,2048) GB" ; then
		sudo dphys-swapfile setup
	fi
	```

* conditional invocation where subsequent actions should occur as long as the patch was attempted (the third optional "true" argument). For example:

	``` bash
	if try_patch "/etc/locale.gen" "setting locales (ignore errors)" true ; then
		sudo dpkg-reconfigure -f noninteractive locales
	fi
	```

<a name="tryMergeFunction"></a>
#### Folder merge function

The `try_merge()` function takes two arguments:

1. A path beginning with a `/` which has the same definition as for [`supporting_file()`](#supportingFileFunction).
2. A comment string summarising the purpose of the merge.

For example:

``` bash
try_merge "/etc/network" "set up custom interfaces"
```

The merge algorithm invokes `supporting_file()` to see if the source path can be found. Calling `supporting_file()` implies both *host-specific* and *general* candidates will be considered, with the *host-specific* form given precedence.

`supporting_file()` will return successfully if the above path exists and is either a file or a non-empty directory. However, `try_merge()` then insists that both the source and target paths lead to *directories*. If both are directories then `rsync` is called to perform a non-overwriting merge. The result code returned by `rsync` becomes the result code returned by `try_merge()`.

If any of the preliminary tests fail, `rsync` is not called and the result code is set to indicate failure.

The `try_merge()` function has two common use patterns:

* unconditional invocation where there are no actions that depend on the success of the merge. For example:

	``` bash
	try_merge "/etc/network" "set up custom interfaces"
	``` 

* conditional invocation where subsequent actions depend on the success of the merge. For example:

	``` bash
	if try_merge "/etc/network" "set up custom interfaces" ; then
		sudo service networking restart
	fi
	```

<a name="patchPreparation"></a>
### Preparing your own patches

PiBuilder can *apply* patches for you, but you still need to *create* each patch.

<a name="patchTools"></a>
#### Tools overview: *diff* and *patch*

Understanding how patching works will help you to develop and test patches before handing them to PiBuilder. Assume:

1. an «original» file (the original supplied as part of Raspbian); and
2. a «final» file (after your editing to make configuration changes).

To create a «patch» file, you use the `diff` tool which is part of Unix:

``` bash
$ diff «original» «final» > «patch»
```

Subsequently, given:

1. a fresh Raspbian install where only «original» exists; plus
2. your «patch» file,

you use the `patch` tool which is also part of Unix:

``` bash
$ patch -bfnz.bak -i «patch» «original»
```

That `patch` command will:

1. copy «original» to «original».bak; and
2. apply «patch» to «original» to convert it to «final».

<a name="patchSummary"></a>
#### Basic process

The basic process for creating a patch file for use in PiBuilder is:

1. Make sure you have a baseline version of the file you want to change. The baseline version of a «target» file should always be whatever was in the Raspbian image you downloaded from the web. Typically, there are two situations:

	* You have run PiBuilder and PiBuilder has already applied a patch to the «target» file. In that case, `«target».bak` is a copy of whatever was in the Raspbian image you downloaded from the web. That means `«target».bak` is your baseline and you don't need to do anything else.
	* The «target» file has never been changed. The currently-active file is your baseline so you need to preserve it by making a copy before you start changing anything. The most likely place where you will be working is the `/etc` directory so `sudo` is usually appropriate:

		``` bash
		$ sudo cp «target» «target».bak
		```

	Note:

	* One of PiBuilder's first actions in the 01 script is to make a copy of `/etc` as `/etc-baseline`. PiBuilder does this before it makes any changes. If you make some changes in the `/etc` directory and only then realise that you forgot to save a baseline copy, you can always fetch a copy of the original file from `/etc-baseline`. 

2. Make whatever changes you need to make to the «target». Sometimes this will involve using `sudo` and a text editor. Other times, you will be able to run a configuration tool like `raspi-config` and it will change the «target» file(s) for you.
3. Create a «patch» file using the `diff` tool. For any given patch file, you always have two options:

	* If the patch file should apply to a **specific** Raspberry Pi, generate the patch file like this:

		``` bash
		$ diff «target».bak «target» > «target».patch@$HOSTNAME
		```

	* If the patch file should apply to **all** of your Raspberry Pis each time they are built, generate the patch file like this:

		``` bash
		$ diff «target».bak «target» > «target».patch
		```

	You can do both. A *host-specific* patch always takes precedence over a *general* patch.

4. Place the «patch» file in its proper location in the PiBuilder structure on your support host (Mac/PC).

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
	resolvconf.conf.patch@«hostname»
	resolvconf.conf.patch
	```

	The proper location for the patch file in the PiBuilder structure structure on your support host is one of the following paths:

	```
	~/PiBuilder/boot/scripts/support/etc/resolvconf.conf.patch@«hostname»
	~/PiBuilder/boot/scripts/support/etc/resolvconf.conf.patch
	```

<a name="configHome"></a>
### Configure home directory

PiBuilder assumes «username» equals "pi". If you choose a different «username», you *might* need to take special care with the following folder and its contents:

```
~/PiBuilder/boot/scripts/support/home/pi/
```

This is the default structure:

```
└── home
    └── pi
        ├── .bashrc
        ├── .config
        │   ├── iotstack_backup
        │   │   └── config.yml
        │   └── rclone
        │       └── rclone.conf
        ├── .gitconfig
        ├── .gitignore_global
        └── crontab
```

Let's suppose that, instead of "pi", you decide to use "me" for your «username». What you *might* need to do is make a copy of the "pi" directory, as in:

``` bash
$ cd ~/PiBuilder/boot/scripts/support/home
$ cp -a pi me
```

If you have followed the instructions about creating a custom branch to hold your changes, your next step would be:

``` bash
$ git add me
$ git commit -m "clone default home directory structure"
```

Note:

* This duplication is *optional*, not *essential*. If PiBuilder is not able to find a specific home folder for «username», it falls back to using "pi" as the source of files being copied into the `/home/«username»` folder on your Raspberry Pi.

<a name="configBashrc"></a>
#### `.bashrc`

The contents of this file are *appended* to the `~/.bashrc` provided automatically by Raspberry Pi OS. The additions:

* source [IOTstackAliases](https://github.com/Paraphraser/IOTstackAliases); 
* enable `DOCKER_BUILDKIT`; and
* define `COMPOSE_PROFILES` to be a synonym for `HOSTNAME`.

See also [`DOT_BASHRC_ACTION`](#dotLoginAction) which explains how to instruct PiBuilder to *replace* your `.bashrc` with a fully custom file.

You can find more information about using compose profiles in [this gist](https://gist.github.com/Paraphraser/eabfedd3f1ac3038dc70a199ef9812de).

<a name="configBackupCfg"></a>
#### `.config/iotstack_backup/config.yml`

This is a placeholder. If you decide to set up [IOTstackBackup](https://github.com/Paraphraser/IOTstackBackup) then you should replace this placeholder with your working configuration.

<a name="configRcloneCfg"></a>
#### `.config/rclone/rclone.conf`

This is a placeholder. If you decide to configure [IOTstackBackup](https://github.com/Paraphraser/IOTstackBackup) to use the RCLONE option (eg so your backups are stored in Dropbox), you should replace this placeholder with your working RCLONE configuration.

<a name="configGit"></a>
#### `.gitconfig`

This is (mostly) a template. At the very least, you should:

1. Replace "Your Name"; and
2. Replace "email@domain.com"

If you have not created a key for signing commits, remove the `signingkey` line, otherwise uncomment it and set the correct value.

Hint:

* You may find it simpler to replace `.gitconfig` with whatever is in `.gitconfig` in your home directory on your support host.

You should only need to change `.gitconfig` in PiBuilder if you also change `.gitconfig` your home directory on your support host. Otherwise, the configuration can be re-used for all of your Raspberry Pis.

<a name="configGitIgnore"></a>
#### `.gitignore_global`

This file has a base set of ignore patterns. You can use it as-is or tailor it to your needs.

<a name="crontab"></a>
#### `crontab`

This is a placeholder containing comments on how to set up cron jobs. PiBuilder will use whatever you supply here to initialise your crontab.



<hr>



<a name="patchPoints"></a>
## Existing customisation points

<a name="etc_dhcpcd_conf"></a>
### DHCP client daemon

* Patch file: `/etc/dhcpcd.conf.patch`

The patch file supplied with PiBuilder adds the line:

```
allowinterfaces eth*,wlan*
```

Explicitly allowing interface participation in DHCP has the side-effect of excluding all other interfaces from DHCP participation. IOTstack uses this approach to prevent the virtual interfaces created by Docker from participating in host DHCP. If those interfaces are allowed to participate in DHCP, it can have the effect of freezing the Raspberry Pi as it comes up after a reboot. Docker assigns IP addresses to all virtual interfaces it creates so DHCP participation is not actually necessary.

You can also use this patch file to assign a static IP address to an interface. For example:

```
interface eth0
static ip_address=192.168.132.55/24
static routers=192.168.132.1
```

Another possible use is explicitly forbidding interfaces that might otherwise match the wild-card "allow" above from participating in DHCP. One situation where you might need to do this is if you defined VLAN interfaces in `/etc/networks` and assigned static IP addresses there. Then you would want to exclude them from DHCP:

```
denyinterfaces eth0,eth0.1,eth0.2
``` 

See also [Configuring Static IP addresses on Raspbian](./docs/ip.md).

<a name="etc_docker_daemon"></a>
### Docker daemon

* Source file: `/etc/docker/daemon.json`

If the source file (in general or host-specific form) exists in the support directory, it is copied into place. One useful thing you can do with this file is to limit the size of your logs:

``` json
{
  "log-driver": "local",
  "log-opts": {
    "max-size": "1m"
  }
}
```

See also:

1. [Local logging](https://docs.docker.com/config/containers/logging/local/).
2. [Daemon configuration](https://docs.docker.com/engine/reference/commandline/dockerd/#daemon-configuration-file).

<a name="etc_dphys_swapfile"></a>
### System swap-file

* Controlling variable: `VM_SWAP`
* Patch file: `/etc/dphys-swapfile.patch`

The patch file supplied with PiBuilder sets the conditions such that the default for swap space is twice the amount of physical RAM, capped at a limit of 2GB. This will be 2GB for any Raspberry Pi with 1GB or more of real RAM. You can, however, change this arrangement to suit your needs, either by altering the supplied patch file or providing a host-specific override.

If `VM_SWAP` is set to:

- `disable`, no swapping occurs. This may be appropriate if your Raspberry Pi boots from SD and you want to avoid wear and tear on the card.
- `automatic`:

	- If the Pi is running from an SD card, this is the same as `disable`.
	- Otherwise the patched version of `/etc/dphys-swapfile` is implemented. This is the recommended option if your Raspberry Pi boots from SSD or HD.

- `custom` is equivalent to `automatic` but it does not check if your system is running from SD. If you want to enable swap on an SD system, this or `default` are the options to use.

- `default` makes no changes to the virtual memory system. The current Raspberry Pi OS defaults enable virtual memory swapping with a swap file size of 100MB. This is perfectly workable on systems with 4GB of RAM or more.

If `VM_SWAP` is not set, it defaults to `automatic`.

Running out of RAM causes swapping to occur and that, in turn, has both a performance penalty (because SD cards are quite slow) and increases the wear and tear on the SD card (leading to a heightened risk of failure). There are two main causes of limited RAM:

- Insufficient physical memory. A good example is a Raspberry Pi Zero W2 which only has 512MB to start with; and/or
- Expecting your Raspberry Pi to do too much work, such as running a significant number of containers which either have large memory footprints, or cause a lot of I/O and consume cache buffers, or both.

If you disable VM swapping by setting `VM_SWAP` to `disable`, but you later decide to re-enable swapping, run these commands:

``` bash
$ sudo systemctl enable dphys-swapfile.service
$ sudo reboot
```

You can always check if swapping is enabled using the `swapon -s` command. Silence means swapping is disabled.

It is important to appreciate that VM swapping is not **bad**. Please don't disable swapping without giving it some thought. If you can afford to add an SSD, you'll get a better result with swapping enabled than if you stick with the SD and disable swapping.

<a name="etc_defaults_grub"></a>
### GRUB

* Configuration directory: `/etc/default/grub.d`

Raspberry Pi OS does not use GRUB so you should ignore this section if you are using PiBuilder on a Raspberry Pi.

However, [GRUB](https://en.wikipedia.org/wiki/GNU_GRUB) (Grand Unified Bootloader) is common in other environments such as Debian native or Debian-in-Proxmox. In such cases, the contents of the PiBuilder configuration directory are merged with its equivalent on the system under construction, and then `update-grub` is invoked.

<a name="etc_locales"></a>
### Locales

* Patch file: `/etc/locale.gen.patch`

Any patch file should always retain "en_GB.UTF-8" because that's assumed for the Raspberry Pi. If you really want to remove that locale then you can do so after the build using `raspi-config`.

Providing `LOCALE_LANG` is defined and contains a value which is active after `/etc/locale.gen` has been patched, then that will be made the active locale.

<a name="etc_network"></a>
### Network interfaces

* Configuration directory: `/etc/network`

PiBuilder does not include a default directory. If you supply a general or host-specific directory, its contents will be merged with `/etc/network`. Network definitions are almost always highly host-specific so you should probably think in those terms.

<a name="etc_rc_local"></a>
### Network interface monitoring

NetworkManager already takes care of keeping interfaces alive so the mechanism discussed in this section is not installed on systems where NetworkManager is running.

See [Do your Raspberry Pi's Network Interfaces freeze?](https://gist.github.com/Paraphraser/305f7c70e798a844d25293d496916e77) for the background to this.

* Patch file: `/etc/rc.local.patch`
* Support script: `/usr/bin/isc-dhcp-fix.sh`

Several preconditions need to be met before this mechanism will be installed:

1. NetworkManager must be inactive. 
2. `/etc/rc.local` must be world-executable and have non-zero length. Debian and Ubuntu typically create an empty `rc.local` and without execute permission.
3. `PiBuilder/boot/scripts/support/usr/bin/usr/bin/isc-dhcp-fix.sh` (or a host-specific version) must exist. It exists in the PiBuilder release but might be removed in customised versions.

If the preconditions are met:

1. `isc-dhcp-fix.sh` is copied into place in `/usr/bin`; then
2. If `/etc/rc.local.patch` is found, it is used to patch `/etc/rc.local`. The default patch adds this line:

	```
	# /usr/bin/isc-dhcp-fix.sh &
	```

3. If that **inactive** line is found in the patched `/etc/rc.local` then PiBuilder checks `eth0` and `wlan0`, adds each active interface to the command, and removes the comment mark. For example, if both interfaces are active, the result will be:

	```
	/usr/bin/isc-dhcp-fix.sh eth0 wlan0 &
	```
	
	If neither interface exists (which may well be the case on non-Raspberry Pi systems), the comment is left in place. 

If you don't want any of this to happen, you can either remove `/usr/bin/isc-dhcp-fix.sh` (or replace it with a do-nothing script) or remove the line added by the patch in step 2. 

<a name="etc_resolvconf_conf"></a>
### DNS resolver

* Patch file: `/etc/resolvconf.conf.patch`

There is no default patch. If you supply a general or host-specific patch file, you can achieve things like:

1. Add a default search domain:

	```
	search_domains=my.domain.com
	```

2. Tell a host to use itself for DNS resolution (eg running BIND9 or PiHole), with a fallback to Google:

	```
	name_servers="127.0.0.1 8.8.8.8"
	resolv_conf_local_only=NO
	```

See also [Configuring DNS for Raspbian](./docs/dns.md).

<a name="etc_samba_smb_conf"></a>
### Samba (SMB)

* Configuration file: `/etc/samba/smb.conf`

PiBuilder does not include a default configuration file for SAMBA. If you provide a general or host-specific configuration file then PiBuilder will install and activate SAMBA for you.

See also [Enabling SAMBA](./docs/samba.md).

<a name="etc_ssh"></a>
### Secure Shell (SSH)

* Zipped replacement directory: `/etc/ssh/etc-ssh-backup.tar.gz@$HOSTNAME`

If the `.gz` is found, it is unpacked and the contents used to replace `/etc/ssh`. This lets you preserve a host's SSH identity across builds. It is particularly useful if you use SSH certificates. See also [Some words about SSH](./docs/ssh.md).

<a name="etc_sysctl_d"></a>
### Kernel parameters

* Merge folder: `/etc/sysctl.d` (new method, recommended)

The recommended method is files (not patches) placed in `/etc/sysctl.d`. The default supplied with PiBuilder contains instructions to disable IPv6. You can either add to that file or supply additional `.conf` files of your own.

<a name="etc_systemd_journald_conf"></a>
### Journal control

* Patch file: `/etc/systemd/journald.conf.patch`

The default patch file changes the system logging level to reduce endless docker-runtime mount messages.

<a name="etc_systemd_timesyncd_conf"></a>
### Time synchronisation

* Patch file: `/etc/systemd/timesyncd.conf.patch`

There is no default patch. If you supply a general or host-specific patch, it can be used to set up a more geographically-appropriate source from which your Raspberry Pi can obtain its time.

For more information, see [Network Time Protocol - setting your closest servers](./docs/ntp.md).

<a name="etc_udev_rules_d"></a>
### Dynamic device management (UDEV)

* Configuration directory: `/etc/udev/rules.d`

PiBuilder provides an empty `rules.d` folder. If you place any UDEV rules files in this folder, or if you provide a host-specific folder, the contents of the folder will be copied onto the target system.

The copy is done without replacement. In other words, if a rule file of the same name already exists on the target system, it won't be replaced with the version from PiBuilder.

<a name="customBuild"></a>
## Using your custom branch in a build

When you want to use your customised version of PiBuildet, instead of cloning PiBuilder from GitHub, clone your customised version from your support host. The basic syntax is:

``` bash
$ git clone -b «branch» «user»@«host»:«remotePath» ~/PiBuilder
```

Here's an example. Assume:

1. The «branch» you are using in PiBuilder to hold your changes is called "custom".
2. Your «user» name on your support host is "edmund".
3. Your «support» host is named "everest" and can be reached via:

	- The IP address 192.168.1.100 ; or
	- The multicast DNS (mDNS) name "everest.local" ; or
	- The fully-qualified domain name (FQDN) "everest.my.domain.com"

4. The PiBuilder directory on "everest" is located in Edmund's home directory.

Any of the following commands should work:

* via IP address:

	``` bash
	$ git clone -b custom edmund@192.168.1.100:PiBuilder ~/PiBuilder
	```

* via mDNS name:

	``` bash
	$ git clone -b custom edmund@everest.local:PiBuilder ~/PiBuilder
	```

* via FQDN:

	``` bash
	$ git clone -b custom edmund@everest.my.domain.com:PiBuilder ~/PiBuilder
	```

In each case:

1. `:PiBuilder` is interpreted as *relative* to Edmund's home directory on "everest". Alternatives:

	- In a sub-folder of Edmund's home directory: `:path/to/PiBuilder`; or
	- An absolute path on "everest": `:/path/to/PiBuilder`.

2. `~/PiBuilder` is the path on the local host (ie the Raspberry Pi) where the clone will be placed.

Notes:

- SSH will probably present a TOFU (Trust On First Use) challenge; and then
- Ask for Edmund's password on "everest".

<a name="originalBuild"></a>
### Original build method still works

The original PiBuilder build method still works *on the Raspberry Pi* but there are differences depending on whether you are installing Raspberry Pi OS Bullseye (or earlier), or Raspberry Pi OS Bookworm.

The steps are:

1. Image your media (SD/SSD). Although you can change the default, Raspberry Pi Imager normally ejects the media at the end of the process.
2. Mount the boot partition on your support host. This can be as simple as physically removing and re-connecting the media and waiting for the operating system on your support host to mount the media.
3. Identify the name of the boot partition. If you are building a system based on:

	* Bullseye (or earlier), the boot partition has the name "boot".
	* Bookworm, the boot partition has the name "bootfs".

4. Copy the **contents** of the PiBuilder `boot` **directory** to the boot **partition**. If your support host is:

	* macOS, you can perform the copying operation by running:

		``` bash
		$ ./setup_boot_volume.sh
		```
	
		> On macOS, the script detects whether `/Volumes/boot` or `/Volumes/bootfs` has mounted and adapts accordingly.
		
	* Linux, you will need to pass the correct path to the boot partition. Example:

		``` bash
		$ ./setup_boot_volume.sh path/to/boot-or-bootfs-partition
		```
				
	* Windows, the `setup_boot_volume.sh` script will not run. You need to copy the **contents** of the `boot` **directory** to the drive where the boot **partition** has mounted.

5. Move the media to your Raspberry Pi and apply power.
6. Connect to your Pi via SSH and run the scripts. If you are building a system based on:

	* Bullseye (or earlier), you can run the first script like this:

		``` bash
		$ /boot/scripts/01_setup.sh «newHostName»
		```
		
	* Bookworm, you can run the first script like this:

		``` bash
		$ /boot/firmware/scripts/01_setup.sh «newHostName»
		```

You can use this older method with either a clean clone of PiBuilder from GitHub or with a local repository containing your own customisations.

The reason why the PiBuilder documentation now focuses on the newer method is because it will also work in situations where the boot partition does not exist (or you can't get to it easily), such as Proxmox VE, or starting with a Debian install on non-Pi hardware, or starting with a non-Raspberry Pi OS on Raspberry Pi hardware.

<a name="githubSync"></a>
## Keeping in sync with GitHub

The instructions in [Getting Started](#gettingStarted) recommended that you create a Git branch ("custom") to hold your customisations. If you did not do that, please do so now:

``` bash
$ cd ~/PiBuilder
$ git checkout -b custom
```

Notes:

* any changes you may have made *before* creating the "custom" branch will become part of the "custom" branch. You won't lose anything. After you "add" and "commit" your changes on the "custom" branch, the "master" branch will be a faithful copy of the PiBuilder repository on GitHub at the moment you first cloned it.
* once the "custom" branch becomes your working branch, there should be no need to switch branches inside the PiBuilder repository. The instructions in this section assume you are always in the "custom" branch.

From time to time as you make changes, you should run:

``` bash
$ git status
```

Add any new or modified files or folders using:

``` bash
$ git add «path»
```

Note:

* You can't add an empty folder to a Git repository. A folder must contain at least one file before Git will consider it for inclusion.

Whenever you reach a logical milestone, commit your changes:

``` bash
$ get commit -m "added a patch for something or other"
```

> naturally, you will want to use a far more informative commit message!

Periodically, you will want to check for updates to PiBuilder on GitHub:

``` bash
$ git fetch origin master:master
```

That pulls changes into the master branch. Next, you will want to merge those changes into your "custom" branch:

``` bash
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

		``` bash
		$ git add «filename»
		```

	5. If more than one file was marked as being in conflict, start over from step 1. You can always refresh your memory on which files are still in conflict by:

		``` bash
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

``` bash
$ git status
``` 

For each file mentioned in the status list that is not in the "Changes to be committed" list, run:

``` bash
$ git add «filename»
```

The last step is to commit the merged changes to your own branch:

``` bash
$ git commit -m "merged with GitHub updates"
```

Now you are in sync with GitHub.
