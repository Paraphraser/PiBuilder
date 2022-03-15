# VNC + PiBuilder

## <a name="toc"> contents </a>

- [why VNC is not enabled by default](#theStory)
- [enabling VNC: the magic incantation](#magicIncantation)

	- [Step 1: change the boot mode](#setBootMode)
	- [Step 2: set the screen resolution](#setResolution)
	- [Step 3: enable the service](#enableService)

- [connecting over VNC](#connectVNC)
- [changing your VNC password](#passwordChange)
- [about `lxpanel`](#aboutlxpanel)

## <a name="theStory"> why VNC is not enabled by default </a>

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

## <a name="magicIncantation"> enabling VNC: the magic incantation </a>

Note:

* These instructions refer to `raspi-config`. That Python application is constantly evolving and is forever adding, removing and altering menu options. If the screen shots here differ from what you see on your own screen, you will have to follow your nose.

### <a name="setBootMode"> Step 1: change the boot mode to "boot to desktop with auto-login" </a>

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

	Tip:

	* Before you press <kbd>return</kbd> at step 5, start a `ping` command running on another computer (Linux, macOS, Windows) directed to the IP address of your Raspberry Pi. You should expect ping replies to stop shortly after you tell the Raspberry Pi to reboot by pressing <kbd>return</kbd>. If ping replies persist for more than 10 seconds then you can probably conclude that the Raspberry Pi has hung on the way down.

3. Wait for the system to reboot. If your Raspberry Pi appears to hang, remove and re-connect the power.

### <a name="setResolution"> Step 2: set the VNC screen resolution </a>

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

### <a name="enableService"> Step 3: enable the VNC service </a>

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

## <a name="connectVNC"> connecting over VNC </a>

The basic URL is:

```
vnc://«host»:«port»
```

where `«host»` is any of:

* an IP address (eg 192.168.1.10)
* a multicast domain name (eg iot-hub.local)
* a domain name (eg iot-hub.mydomain.com)

The `«port»` number defaults to 5900 and can usually be omitted.

If you are prompted for a username, use "pi".

You should be prompted for a password. Assuming you used PiBuilder to build your Raspberry Pi, the VNC password will be the same as the new password you entered for user "pi" when you started the 01 script. After password verification, you should expect to see a screen like:

![boot to desktop with auto-login](./images/vnc4.jpg)

That screen shot was taken on:

* a 4GB Raspberry Pi 4 B
* image `2022-01-28-raspios-bullseye-arm64.zip` (full 64-bit Debian Bullseye)
* built with PiBuilder (as at 2022-03-15)
* VNC activated by following the [magic incantation](#magicIncantation) above ***after*** the 05 script had completed.

At that point, you should click on the <kbd>Next</kbd> button and follow your nose. I recommend:

1. Responding to the password-change prompt using the same password as you just used to connect. It's not really clear what the VNC password-change screen actually affects. It does not seem to change anything but I think it's best to avoid any possibility of confusion by keeping the passwords the same. See [changing your VNC password](#passwordChange) if you do want to change your VNC password. That actually works!
2. Skipping the WiFi screen. WiFi is either already set up by PiBuilder or you told it not to do that by omitting `wpa_supplicant.conf`.
3. Skipping the software update screen. PiBuilder has just done all that.

## <a name="passwordChange"> changing your VNC password </a>

The PiBuilder 01 script uses the `vncpasswd` command to set the VNC password to be the same as the user "pi" password. That means the VNC password will already be in place when you enable the VNC service.

The VNC password is stored as a hash in the following file:

```
/etc/vnc/config.d/common.custom
```

You can change the password by running the following commands:

```bash
$ sudo vncpasswd -file /etc/vnc/config.d/common.custom
$ sudo systemctl restart vncserver-x11-serviced
```

The `vncpasswd` command prompts twice for a new password. The `restart` causes the change to take effect.

## <a name="aboutlxpanel"> about `lxpanel` </a>

As well as avoiding hangs on reboot, setting the Raspberry Pi boot mode to "Console" stops the `lxpanel` daemon from launching at boot time.

The `lxpanel` daemon has an intermittent fault where it can go into a tight infinite loop. Such a CPU loop:

* Makes the Raspberry Pi **extremely** sluggish, to the point where Docker containers can stop working properly;
* Drives CPU temperature through the roof, to the point where Raspberry Pi OS throttles the system, further exacerbating problems with Docker containers.

When the fault manifests, you can still (just) get access via SSH but you have to be patient. You can cure the problem by:

```bash
$ sudo killall lxpanel
$ sudo reboot
```

I took the view that Raspberry Pi's running IOTstack were there to provide reliable services for IoT devices, that VNC was a nice-to-have, but that the occasional misbehaviour by `lxpanel` leading to service interruption meant that I should do without VNC.

