# Maintaining docker + docker-compose

A lot of issues raised on [SensorsIot/IOTstack](https://github.com/SensorsIot/IOTstack/issues) and the [IOTstack Discord channel](https://discord.gg/ZpKHnks) turn out to have improper installation of *docker* and/or *docker-compose* as their underlying cause. The *hows* and *whys* of this happening are not really important. These instructions are intended to help you overcome such problems.

You can follow these instructions even if you did not use PiBuilder to build your Raspberry Pi in the first place.

- [General caveat](#caveat)
- [Preparation](#preparation)
- [The nuclear option – getting a clean slate](#nuclearOption)

	- [Uninstalling docker, docker-compose](#uninstalling)
	- [Re-installing docker, docker-compose](#reinstalling)

- [Upgrading docker](#upgradingDocker)
- [Upgrading docker-compose](#upgradingCompose)

	- [Option 1: let `apt` do the work](#composeByApt)
	- [Option 2: upgrade docker-compose by hand](#composeByHand)
	- [Option 3: go back to letting `apt` do the work](#recomposeByApt)

<hr>

<a name="caveat"></a>
## General caveats

It's important to realise that, sometimes, things just get so messed up under the hood of a Raspberry Pi that a complete rebuild is your best solution. If you try these instructions but you still can't resolve the problem, it's likely that a complete rebuild is in your future. That is, of course, PiBuilder's raison d'être.

<a name="preparation"></a>
## Preparation

Clone PiBuilder onto your Raspberry Pi:

```
$ cd
$ git clone https://github.com/Paraphraser/PiBuilder.git
```

It does not matter whether or not you used PiBuilder to build your Raspberry Pi. The idea here is to make sure you have the latest and greatest version of PiBuilder on your Raspberry Pi. If you *previously* cloned PiBuilder, make sure it is up-to-date:
	
```
$ cd ~/PiBuilder
$ git pull origin master
```

<a name="nuclearOption"></a>
## The nuclear option – getting a clean slate

<a name="uninstalling"></a>
### Uninstalling docker, docker-compose

1. Is any part of IOTstack running? If yes, run:

	```bash
	$ cd ~/IOTstack
	$ docker-compose down
	```

2. Are any other containers running, such as might have been started with `docker run`? If yes, you need to terminate each one. Here's an example:

	* List any running containers:

		```bash
		$ docker ps --format "table {{.ID}}\t{{.Names}}"
		CONTAINER ID   NAMES
		060c1cbe3606   grafana
		```

	* To terminate Grafana by using its container ID:

		```bash
		$ docker stop 060c1cbe3606
		060c1cbe3606
		$ docker rm -f 060c1cbe3606
		060c1cbe3606
		```

		The reason for using the ID rather than the name is that containers started via `docker run` sometimes do not have meaningful names.

	Repeat this process until there are no more running containers.

3. Uninstall docker and docker-compose:

	```bash
	$ cd ~/PiBuilder/boot/scripts/helpers
	$ ./uninstall_docker.sh
	$ ./uninstall_docker-compose.sh
	$ sudo reboot
	```

	Notes:
	
	* It is safe to run both of these `uninstall_` commands even if you are not sure whether docker and docker-compose are installed.
	* The reboot is **important**. Trying to re-install docker without first doing a reboot risks creating a mess on your system.

<a name="reinstalling"></a>
### Re-installing docker, docker-compose

PiBuilder's `04_setup.sh` script installs docker and docker-compose:

```bash
$ cd ~/PiBuilder/boot/scripts
$ ./04_setup.sh
```

Note:

* It is **not** appropriate to run `04_setup.sh` unless you have just gone through all the steps in [Uninstalling docker, docker-compose](#uninstalling).

The `04_setup.sh` script ends with a reboot. To restart your IOTstack:

```bash
$ cd ~/IOTstack
$ docker-compose up -d
```

<a name="upgradingDocker"></a>
## Upgrading docker

After Docker has been installed by the `04_setup.sh` script, it is upgraded via `apt`. You can use the standard system maintenance commands:

```
$ sudo apt update
$ apt list --upgradable
$ sudo apt upgrade
```

Note:

* If an `apt upgrade` installs a new version of `docker`, that *will* restart your stack. That's why the `apt list` command is in the middle - so you can see whether `docker` will be upgraded and decide whether to proceed or defer the upgrade.

<a name="upgradingCompose"></a>
## Upgrading docker-compose

This is a bit complicated. Start by running this command:

```
$ docker-compose version
```

If the answer is 1.29.2 or earlier then you should follow the steps above at:

* [The nuclear option – getting a clean slate](#nuclearOption)
 
If you have just run the `04_setup.sh` script (either because you have just done a PiBuilder installation or because you were following these instructions) then docker-compose will be at version 2.x.x.

<a name="composeByApt"></a>
### Option 1: let `apt` do the work

Once docker-compose has been installed by the `04_setup.sh` script, it can be upgraded via `apt` so you can use the standard system maintenance commands:

```
$ sudo apt update
$ sudo apt upgrade
```

<a name="composeByHand"></a>
### Option 2: upgrade docker-compose by hand

The problem with letting `apt` do the work is there seem to be significant delays between new versions of docker-compose being released on GitHub and making their way into the `apt` repositories.

At the time of writing (2025-04-17):

* the `apt` version is v2.34.0. It was released on 2025-03-14.
* the [releases page](https://github.com/docker/compose/releases) has advanced to v2.35.0.

If you need a more-recent version of docker-compose, proceed like this:

1. Move to the scripts directory:

	```bash
	$ cd ~/PiBuilder/boot/scripts/helpers
	```

2. Uninstall all versions of docker-compose:

	```bash
	$ ./uninstall_docker-compose.sh
	```

3. Do one of the following:

	* **EITHER** install the desired version by passing an explicit version number:

		```bash
		$ sudo ./install_docker-compose.sh v2.35.0
		```

	* **OR** install the latest version by omitting the version number:

		```bash
		$ sudo ./install_docker-compose.sh
		```

Notes:

1. Replace "v2.35.0" with whatever version you need. The leading "v" is required.
2. This uninstall/upgrade sequence can also be used to downgrade to any v2.x.x.
3. Once you have used the `install_docker-compose.sh` script to upgrade docker-compose, the [`apt` method](#composeByApt) will no longer work. If you want to revert to the `apt` method, you will need [option 3](#recomposeByApt). 

<a name="recomposeByApt"></a>
### Option 3: go back to letting `apt` do the work

You've tried [upgrading docker-compose by hand](#composeByHand) but you've decided to go back to [letting `apt` do the work](#composeByApt):

```bash
$ cd ~/PiBuilder/boot/scripts/helpers
$ ./uninstall_docker-compose.sh
$ ./install_docker-compose-plugin.sh
```

Thereafter, an `apt update` followed by an `apt upgrade` will update `docker-compose-plugin` as and when a new version is released via the `apt` repositories. This is significantly slower than the speed with which new releases appear on the [releases page](https://github.com/docker/compose/releases). The release schedule for `docker-compose-plugin` appears to be tied to the release schedule for `docker-ce`.
