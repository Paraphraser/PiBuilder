# VNC + Desktop + PiBuilder

<a name="toc"></a>
## contents

- [why PiBuilder disables RealVNC and Desktop](#theStory)

- [enabling RealVNC](#realVNCmethod)

	- [Step 1: create a VNC password](#setPassRealVNC)
	- [Step 2: change the boot mode](#setBootModeRealVNC)
	- [Step 3: set the VNC screen resolution](#setResolutionRealVNC)
	- [Step 4: enable the RealVNC service](#enableRealVNC)
	- [Step 5: connecting to RealVNC](#connectToRealVNC)

- [enabling TightVNC](#tightVNCmethod)

	- [Step 1: install packages](#installTightVNC)
	- [Step 2: create a VNC password](#setPassTightVNC)
	- [Step 3: reconfigure](#configureTightVNC)
	- [Step 4: connecting to TightVNC](#connectToTightVNC)
	- [Step 5: enabling TightVNC](#enableTightVNC)

		- [manual](#manualTightVNC)
		- [automatic](#autoTightVNC)

	- [A better browser](#betterBrowser)

<a name="theStory"></a>
## why PiBuilder disables RealVNC and Desktop

A [thread on Discord](https://discord.com/channels/638610460567928832/638610461109256194/949203175758524499) began with the following post:

> Hi guys, my friend installed IOTstack via PiBuilder and has problem with VNC. Next he tried standard installation and VNC works correctly.

The reason why VNC (and, more specifically, RealVNC) doesn't ***seem*** to work with PiBuilder is explained by the Raspberry Pi's "boot mode". RealVNC depends on the boot mode being set to "Desktop" whereas PiBuilder sets the boot mode to "Console".

PiBuilder uses "Console" for two reasons:

1. It minimises the incidence of the Raspberry Pi hanging when the various PiBuilder scripts trigger reboots. The hangs don't appear to do any *harm* but the user needs to recognise the hung condition and cure the problem by removing and re-applying power. That's a real nuisance and doesn't inspire confidence in PiBuilder when, in fact, the hangs probably have little-to-nothing to do with PiBuilder.
2. It solves an intermittent problem associated with `lxpanel`. This does not actually affect the PiBuilder build process but it can cause trouble once the system is running your Docker containers.

<a name="aboutlxpanel"></a>The `lxpanel` daemon has an intermittent fault where it can go into a tight infinite loop. The condition:

* Makes the Raspberry Pi **extremely** sluggish, to the point where Docker containers can stop working properly;
* Drives CPU temperature through the roof, to the point where Raspberry Pi OS throttles the system, further exacerbating problems with Docker containers.

When the `lxpanel` fault manifests, you can still (just) get access via SSH but you have to be patient. Once you gain access, you can cure the problem by:

```bash
$ sudo killall lxpanel
$ sudo reboot
```

I took the view that Raspberry Pis running IOTstack were there to provide stable, reliable services for IoT devices. Periodic misbehaviour by `lxpanel` causing service interruptions was a problem I didn't need.

The issue with `lxpanel` is very old and has been reported many times. For example:

* [Apr 2011](https://bbs.archlinux.org/viewtopic.php?id=116144)
* [Sep 2015](https://forums.raspberrypi.com/viewtopic.php?t=121022)
* [Apr 2018](https://github.com/raspberrypi/linux/issues/2518)
* [Feb 2019](https://raspberrypi.stackexchange.com/questions/94330/lxpanel-using-100-cpu-1-core)

I have not found **any** evidence that it is being worked on.

It is important to realise that the changing the boot mode to "Console" actually has two effects:

1. If you have a screen connected to one of the Pi's HDMI ports, that screen will show the "console" (like a Terminal session) rather than the "Desktop" (the [PIXEL](https://www.raspberrypi.com/news/introducing-pixel/) windowing environment).

	If you want an HDMI screen to show the Desktop then your only choice is to change the boot mode and that, in turn, will activate the `lxpanel` daemon, thereby increasing the chances of service interruptions.
	
2. RealVNC can still be enabled independently of the boot mode but it will not "work" because it depends on PIXEL. All the remote user will see is an error message.

	In other words, RealVNC not working is really a casualty of avoiding the `lxpanel` problem, rather than a problem with RealVNC per se.

In addition to these server-side issues, I have also had trouble using the VNC client built into the macOS "Connect to Server…" command to connect with RealVNC-based services on Raspberry Pis. While that's a macOS-specific issue, taken together with the other problems, it suggests more development work might be needed before the Raspberry Pi's implementation of RealVNC can be considered "industrial strength".

I have yet to experience equivalent problems with [TightVNC](https://www.tightvnc.com). In addition, connecting to TightVNC-based services from macOS "just works". Right out of the box. That is why I recommend it.

Bottom line: RealVNC and PiBuilder are neither mutually exclusive nor incompatible. It's your machine so it's your decision. If you want RealVNC enabled on a system built by PiBuilder, you just need to do it yourself *after* PiBuilder has finished.

<a name="realVNCmethod"></a>
## enabling RealVNC

RealVNC is bundled with Raspberry Pi OS and is the VNC method officially supported by the Raspberry Pi Foundation. While this might make it sound like it is superior, in practice it leads to performance problems when [`lxpanel` misbehaves](#aboutlxpanel).

If you decide that the benefit of RealVNC outweighs the risk of performance problems, you can enable RealVNC by following the instructions in this section.

The alternative is TightVNC which is discussed in the [next section](#tightVNCmethod).

<a name="setPassRealVNC"></a>
### Step 1: create a VNC password

PiBuilder provides a helper script:

``` bash
$ ~/PiBuilder/boot/scripts/helpers/set_vnc_password.sh
```

The `set_vnc_password.sh` script takes no arguments. It does all the work of:

1. Prompting, twice, for a password; then
2. Initialising /etc/vnc/config.d/common.custom; and
3. If the RealVNC service is already running, restarting the service.

You can use `set_vnc_password.sh` to initialise your first VNC password, or to change an existing VNC password.

<a name="setBootModeRealVNC"></a>
### Step 2: change the boot mode 

Change the boot mode to "boot to desktop with auto-login":

1. Run the command:

	```bash
	$ sudo raspi-config
	```

2. Work through the numbered steps:

	![boot to desktop with auto-login](./images/vnc1.jpg)

	In words:

	1. Use the <kbd>&#x2B06;</kbd> and <kbd>&#x2B07;</kbd> keys to select `System Options` and press <kbd>return</kbd>.
	2. Use the <kbd>&#x2B06;</kbd> and <kbd>&#x2B07;</kbd> keys to select `Boot / Auto Login` and press <kbd>return</kbd>.
	3. Use the <kbd>&#x2B06;</kbd> and <kbd>&#x2B07;</kbd> keys to select `Desktop Autologin` and press <kbd>return</kbd>.
	4. Use the <kbd>tab</kbd> key to select `<finish>` and and press <kbd>return</kbd>.
	5. Use the <kbd>tab</kbd> key to select `<Yes>` and and press <kbd>return</kbd>.

	*Pro tip:*

	* it is a good idea to start a `ping` to your Raspberry Pi from *another* host before you initiate a reboot. The expected pattern is:

		1. ping replies arrive while the Pi is still running.
		2. ping replies cease shortly after the Pi starts to go down.
		3. ping replies resume after the Pi starts to come up.

		If ping replies do not cease once a reboot has been triggered, that's a good indication that the Pi has hung on the way down.

3. Wait for the system to reboot. If your Raspberry Pi appears to hang, remove and re-connect the power.

<a name="setResolutionRealVNC"></a>
### Step 3: set the VNC screen resolution

1. Run the command:

	```bash
	$ sudo raspi-config
	```

2. Work through the numbered steps:

	![set VNC screen resolution](./images/vnc2.jpg)

	In words:

	1. Use the <kbd>&#x2B06;</kbd> and <kbd>&#x2B07;</kbd> keys to select `Display Options` and press <kbd>return</kbd>.
	2. Use the <kbd>&#x2B06;</kbd> and <kbd>&#x2B07;</kbd> keys to select `VNC Resolution` and press <kbd>return</kbd>.
	3. Use the <kbd>&#x2B06;</kbd> and <kbd>&#x2B07;</kbd> keys to select `1920x1080` (or another resolution of your choice) and press <kbd>return</kbd>.
	4. Press <kbd>return</kbd> to accept `<Ok>`.

3. You are returned to the `raspi-config` main menu.

<a name="enableRealVNC"></a>
### Step 4: enable the RealVNC service

1. Assuming the `raspi-config` application is still running…

2. Work through the numbered steps:

	![start VNC service](./images/vnc3.jpg)

	In words:

	1. Use the <kbd>&#x2B06;</kbd> and <kbd>&#x2B07;</kbd> keys to select `Interface Options` and press <kbd>return</kbd>.
	2. Use the <kbd>&#x2B06;</kbd> and <kbd>&#x2B07;</kbd> keys to select `VNC` and press <kbd>return</kbd>.
	3. Use the <kbd>tab</kbd> key to select `<Yes>` and press <kbd>return</kbd>.
	4. Press <kbd>return</kbd> to accept `<Ok>`. This returns you to the main menu.
	5. Use the <kbd>tab</kbd> key to select `<Finish>` and press <kbd>return</kbd>.
	6. Use the <kbd>tab</kbd> key to select `<Yes>` and press <kbd>return</kbd>.

3. Wait for the system to reboot. If your Raspberry Pi appears to hang, remove and re-connect the power.

<a name="connectToRealVNC"></a>
### Step 5: connecting to RealVNC

The basic URL is:

```
vnc://«host»:«port»
```

where `«host»` is any of:

* an IP address (eg 192.168.1.10)
* a multicast domain name (eg iot-hub.local)
* a domain name (eg iot-hub.mydomain.com)

The `«port»` number defaults to 5900 and can usually be omitted. You should be prompted for a password. Respond with the password you set up in [Step 1: create a VNC password](#setPassRealVNC). After verification, you should expect to see the desktop.

Alternatively, you may see a screen with a login dialog. That is what would happen if you chose boot mode B3 (Desktop, requiring user to login) in [Step 2: change the boot mode to "boot to desktop with auto-login"](#setBootModeRealVNC). In that case, enter a valid username (eg "pi") and password.

<a name="tightVNCmethod"></a>
## enabling TightVNC

These instructions were adapted from [How to Install and Configure TightVNC on Ubuntu](https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-vnc-on-ubuntu-20-04). I have tested these instructions on both Bullseye and Bookworm.

<a name="installTightVNC"></a>
### Step 1: install packages

``` bash
$ sudo apt update
$ sudo apt install -y xfce4 xfce4-goodies tightvncserver
```

Note:

* This uninstalls the RealVNC service.

<a name="setPassTightVNC"></a>
### Step 2: create a VNC password

Run:

``` bash
$ vncserver
```

You will be prompted, twice, for a password. This command also initialises the `~/.vnc` directory and starts the TightVNC service with default parameters.

Note:

* If you ever need to change the password, run:

	``` bash
	$ vncpasswd
	```

<a name="configureTightVNC"></a>
### Step 3: reconfigure

First, terminate the service:

``` bash
$ vncserver -kill :1
```

Next, run the following commands:

```bash
$ START="$HOME/.vnc/xstartup"
$ cp "$START" "$START.bak"
$ echo -e '#!/usr/bin/env bash\nxrdb $HOME/.Xresources\nstartxfce4 &\n' >"$START"
```

Notes:

* The single quotes in the `echo` command are **required**.
* The practical effect of the `echo` command is to instruct TightVNC to use the [XFCE Desktop](https://xfce.org).

Download the default options for TightVNC:

``` bash
$ CONFIG="$HOME/.vnc/tightvncserver.conf"
$ wget https://raw.githubusercontent.com/TurboVNC/tightvnc/main/vnc_unixsrc/tightvncserver.conf -O "$CONFIG"
```

* TightVNC defaults to a screen geometry of 1024x768 but you can adjust that by editing:

	```
	~/.vnc/tightvncserver.conf
	```

	I prefer a screen geometry of 1920x1080, which is controlled by the `$geometry` parameter:

	```
	$geometry = "1920x1080";
	```

	Changes take effect when you next start `vncserver`.

Finally, start the service again:

``` bash
$ vncserver
```

<a name="connectToTightVNC"></a>
### Step 4: connecting to TightVNC

The basic URL is:

```
vnc://«host»:5901
```

where `«host»` is any of:

* an IP address (eg 192.168.1.10)
* a multicast domain name (eg iot-hub.local)
* a domain name (eg iot-hub.mydomain.com)

You should be prompted for a password. Respond with the password you set up in [Step 1: create a VNC password](#setPassTightVNC). After verification, you should expect to see the desktop.

TightVNC does **not** encrypt its traffic. Whether this matters will depend on your situation:

* In a home LAN where you control the client device, the server (the Raspberry Pi) and the network infrastructure, it is unlikely to matter.
* If you access your home LAN remotely via WireGuard or ZeroTier, traffic travelling beyond your home network will be encrypted by the VPN so it is unlikely to matter.
* If you had planned to expose port 5901 on your router then it definitely will matter so you should **not** do that. WireGuard or ZeroTier are much safer choices.

There are instructions [here](https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-vnc-on-ubuntu-20-04#step-3-connecting-to-the-vnc-desktop-securely) on how to use SSH port forwarding to secure the VNC traffic. It's essentially the same as a VPN.

<a name="enableTightVNC"></a>
### Step 5: enabling TightVNC

<a name="manualTightVNC"></a>
#### manual

If you only need VNC occasionally, you can start the service on demand with:

``` bash
$ vncserver
```

and then stop the service when it is no longer required:

``` bash
$ vncserver -kill :1
```

Note:

* If you run the `vncserver` command when the service is already running, you will get a second daemon which will claim port 5902 (a third instance would claim port 5903, and so on). To kill an unwanted instance:

	``` bash
	$ vncserver -kill :n
	```

	where "n" is the identifier of the unwanted instance.

<a name="autoTightVNC"></a>
#### automatic

If you want the VNC service to be "always on", there are two methods:

1. Add lines to your `crontab` using `crontab -e`. The basic syntax is:

	```
	@reboot USER=pi /usr/bin/vncserver >/dev/null 2>&1
	```

	Tip:

	* Until you are sure it is working properly, use a command that redirects STDOUT and STDERR to a log file. Example:

		```
		@reboot USER=pi /usr/bin/vncserver >>/home/pi/vnc.log 2>&1
		```

2. Follow the instructions for setting up [TightVNC as a System Service](https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-vnc-on-ubuntu-20-04#step-4-running-vnc-as-a-system-service).

<a name="betterBrowser"></a>
### A better browser

The browser that comes with TightVNC is a bit old. If you want something slightly more up-to-date, run:

```
$ sudo apt install -y chromium-browser
```

[Connect to TightVNC](#connectToTightVNC) and click on the "Web Browser" icon in the Dock. That should launch Chromium.

If the older browser launches, start the Terminal, and run:

```
$ /usr/bin/chromium-browser`
```

Follow its prompts. Thereafter, clicking the "Web Browser" icon in the Dock should launch Chromium.
