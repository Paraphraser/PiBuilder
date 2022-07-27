# VNC + console + PiBuilder

## <a name="toc"></a>contents

- [why VNC and console support is not enabled by default](#theStory)
- [enabling VNC: the magic incantation](#magicIncantation)

	- [Step 1: create a VNC password](#setPassword)
	- [Step 2: change the boot mode](#setBootMode)
	- [Step 3: set the screen resolution](#setResolution)
	- [Step 4: enable the service](#enableService)

- [connecting over VNC](#connectVNC)
- [changing your VNC password](#passwordChange)
- [about `lxpanel`](#aboutlxpanel)

## <a name="theStory"></a> why VNC and console support is not enabled by default

A [thread on Discord](https://discord.com/channels/638610460567928832/638610461109256194/949203175758524499) began with the following post:

> Hi guys, my friend installed IOTstack via PiBuilder and has problem with VNC. Next he tried standard installation and VNC works correctly.

The reason why VNC doesn't ***seem*** to work with PiBuilder is explained by the Raspberry Pi's "boot mode":

* VNC depends on the boot mode being set to "Desktop Autologin"; whereas
* PiBuilder sets the boot mode to "Console".

PiBuilder uses "Console" for two reasons:

1. It seems to minimise the incidence of the Raspberry Pi hanging when the various PiBuilder scripts trigger reboots. The hangs don't appear to do any *harm* but the user needs to recognise the hung condition and cure the problem by removing and re-applying power. That's a real nuisance and doesn't inspire confidence in PiBuilder when, in fact, the hangs probably have little-to-nothing to do with PiBuilder.
2. It solves an intermittent problem associated with `lxpanel`. This does not actually affect the PiBuilder build process but it can cause trouble once the system is running your Docker containers. See [about `lxpanel`](#aboutlxpanel).

I have experimented with a number of approaches based around the idea of supporting an `ENABLE_VNC` option in PiBuilder (which would set boot mode to "Desktop Autologin" and do everything else required to have VNC enabled at the end of the build) but everything I've tried increases the probability of hangs.

VNC also appears to have other problems, such as these messages in the system log:

```
mmm dd hh:mm:SS host vncserver-x11[1275,root]: VendorConfig: Error in Certificate "CN=GlobalSign,O=GlobalSign,OU=GlobalSign Root CA - R2": X.509 Error: Certificate expired
```

I doubt that an expired certificate explains anything but I do think of it as evidence inviting the conclusion that VNC support *might need a little bit more work.*

With all of the above in mind, I've decided that I won't try to support an `ENABLE_VNC` option in PiBuilder until it can be done in a manner which is robust and reliable.

Does that mean that VNC and PiBuilder are mutually exclusive or incompatible?

No! Far from it!

It just means that, if you want VNC enabled on a system built by PiBuilder, you need to do it yourself *after* you have finished running PiBuilder's scripts.

## <a name="magicIncantation"></a>enabling VNC: the magic incantation

Note:

* These instructions refer to `raspi-config`. That Python application is constantly evolving and is forever adding, removing and altering menu options. If the screen shots here differ from what you see on your own screen, you will have to follow your nose.

### <a name="setPassword"></a>Step 1: create a VNC password

The PiBuilder 01 script **used** to set the VNC password to be the same as the password for user "pi". It was convenient to do that in the 01 script because, at that point in the build process, the default login password of "raspberry" was likely to be in effect. It was highly desirable to force a change away from the default password so it was really a case of killing two birds with one stone.

The 2022-04-04 changes to Raspberry Pi OS removed both the default user and default password. At the point in the build process where the 01 script runs, it's safe to assume that the user has already set sensible credentials for the first user account.

Also, setting the VNC and user passwords to be the same has always been a bit of a hack because VNC only recognises the first 8 characters of any password as significant.

The revised PiBuilder 01 script no longer prompts for a password so it can't set up a VNC password. Instead, you run:

```
$ /boot/scripts/helpers/set_vnc_password.sh
```

Remember:

* The `scripts` folder is copied onto your `/boot` partition from your support host so the `set_vnc_password.sh` script will only be in the `helpers` folder if you have done that since the 2022-04-04 changes went into effect. As an alternative, you can download and execute the script like this:

	```bash
	$ wget -q https://raw.githubusercontent.com/Paraphraser/PiBuilder/master/boot/scripts/helpers/set_vnc_password.sh
	$ chmod +x set_vnc_password.sh
	$ ./set_vnc_password.sh
	```

The `set_vnc_password.sh` script takes no arguments. It does all the work of:

1. Prompting, twice, for a password; then
2. Initialising /etc/vnc/config.d/common.custom; and
3. If the VNC service is already running, restarting the service.

You can use `set_vnc_password.sh` to initialise your first VNC password, or to change an existing VNC password.

### <a name="setBootMode"></a>Step 2: change the boot mode to "boot to desktop with auto-login"

1. Run the command:

	```bash
	$ sudo raspi-config
	```

2. Work through the numbered steps:

	![boot to desktop with auto-login](./images/vnc1.jpg)

	In words:

	1. Use the <kbd>⬆︎</kbd> and <kbd>⬇︎</kbd> keys to select `System Options` and press <kbd>return</kbd>.
	2. Use the <kbd>⬆︎</kbd> and <kbd>⬇︎</kbd> keys to select `Boot / Auto Login` and press <kbd>return</kbd>.
	3. Use the <kbd>⬆︎</kbd> and <kbd>⬇︎</kbd> keys to select `Desktop Autologin` and press <kbd>return</kbd>.
	4. Use the <kbd>tab</kbd> key to select `<finish>` and and press <kbd>return</kbd>.
	5. Use the <kbd>tab</kbd> key to select `<Yes>` and and press <kbd>return</kbd>.

	*Pro tip:*
	
	* it is a good idea to start a `ping` to your Raspberry Pi from *another* host before you initiate a reboot. The expected pattern is:
	
		1. ping replies arrive while the Pi is still running.
		2. ping replies cease shortly after the Pi starts to go down.
		3. ping replies resume after the Pi starts to come up.
	
		If ping replies do not cease once a reboot has been triggered, that's a good indication that the Pi has hung on the way down.

3. Wait for the system to reboot. If your Raspberry Pi appears to hang, remove and re-connect the power.

### <a name="setResolution"></a>Step 3: set the VNC screen resolution

1. Run the command:

	```bash
	$ sudo raspi-config
	```

2. Work through the numbered steps:

	![set VNC screen resolution](./images/vnc2.jpg)

	In words:

	1. Use the <kbd>⬆︎</kbd> and <kbd>⬇︎</kbd> keys to select `Display Options` and press <kbd>return</kbd>.
	2. Use the <kbd>⬆︎</kbd> and <kbd>⬇︎</kbd> keys to select `VNC Resolution` and press <kbd>return</kbd>.
	3. Use the <kbd>⬆︎</kbd> and <kbd>⬇︎</kbd> keys to select `1920x1080` (or another resolution of your choice) and press <kbd>return</kbd>.
	4. Press <kbd>return</kbd> to accept `<Ok>`.

3. You are returned to the `raspi-config` main menu.

### <a name="enableService"></a>Step 4: enable the VNC service

1. Assuming the `raspi-config` application is still running…

2. Work through the numbered steps:

	![start VNC service](./images/vnc3.jpg)

	In words:

	1. Use the <kbd>⬆︎</kbd> and <kbd>⬇︎</kbd> keys to select `Interface Options` and press <kbd>return</kbd>.
	2. Use the <kbd>⬆︎</kbd> and <kbd>⬇︎</kbd> keys to select `VNC` and press <kbd>return</kbd>.
	3. Use the <kbd>tab</kbd> key to select `<Yes>` and press <kbd>return</kbd>.
	4. Press <kbd>return</kbd> to accept `<Ok>`. This returns you to the main menu.
	5. Use the <kbd>tab</kbd> key to select `<Finish>` and press <kbd>return</kbd>.
	6. Use the <kbd>tab</kbd> key to select `<Yes>` and press <kbd>return</kbd>.

3. Wait for the system to reboot. If your Raspberry Pi appears to hang, remove and re-connect the power.

## <a name="connectVNC"></a>connecting over VNC

The basic URL is:

```
vnc://«host»:«port»
```

where `«host»` is any of:

* an IP address (eg 192.168.1.10)
* a multicast domain name (eg iot-hub.local)
* a domain name (eg iot-hub.mydomain.com)

The `«port»` number defaults to 5900 and can usually be omitted. You should be prompted for a password. Respond with the password you set up in [Step 1: create a VNC password](#setPassword). After verification, you should expect to the desktop.

Alternatively, you may see a screen with a login dialog. That is what would happen if you chose boot mode B3 (Desktop, requiring user to login) in [Step 2: change the boot mode to "boot to desktop with auto-login"](#setBootMode). In that case, enter a valid username (eg "pi") and password.

## <a name="passwordChange"></a>changing your VNC password

The process for changing your password is the same as setting it up in the first place. See [Step 1: create a VNC password](#setPassword).

## <a name="aboutlxpanel"></a>about `lxpanel`

As well as avoiding hangs on reboot, setting the Raspberry Pi boot mode to "Console" stops the `lxpanel` daemon from launching at boot time.

The `lxpanel` daemon has an intermittent fault where it can go into a tight infinite loop. Such a CPU loop:

* Makes the Raspberry Pi **extremely** sluggish, to the point where Docker containers can stop working properly;
* Drives CPU temperature through the roof, to the point where Raspberry Pi OS throttles the system, further exacerbating problems with Docker containers.

When the fault manifests, you can still (just) get access via SSH but you have to be patient. You can cure the problem by:

```bash
$ sudo killall lxpanel
$ sudo reboot
```

I took the view that Raspberry Pis running IOTstack were there to provide reliable services for IoT devices, that VNC was a nice-to-have, but that the occasional misbehaviour by `lxpanel` leading to service interruption meant that I should do without VNC.

