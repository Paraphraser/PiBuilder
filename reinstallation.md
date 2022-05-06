# Maintaining docker + docker-compose

A lot of issues raised on [SensorsIot/IOTstack](https://github.com/SensorsIot/IOTstack/issues) and the [IOTstack Discord channel](https://discord.gg/ZpKHnks) turn out to have improper installation of *docker* and/or *docker-compose* as their underlying cause. The *hows* and *whys* of this happening are not really important. These instructions are intended to help you overcome such problems.

You can follow these instructions even if you did not use PiBuilder to build your Raspberry Pi in the first place.

- [General caveat](#caveat)
- [Preparation](#preparation)
- [The nuclear option – getting a clean slate](#nuclearOption)

	- [Uninstalling docker, docker-compose](#uninstalling)
	- [Re-installing docker, docker-compose](#reinstalling)

- [Upgrading docker, docker-compose](#upgrading)

	- [Upgrading docker](#upgradeDocker)
	- [Upgrading docker-compose](#upgradeCompose)

<hr>

## <a name="caveat"></a>General caveats

It's important to realise that, sometimes, things just get so messed up under the hood of a Raspberry Pi that a complete rebuild is your best solution. If you try these instructions but you still can't resolve the problem, it's likely that a complete rebuild is in your future. That is, of course, PiBuilder's raison d'être.

## <a name="preparation"></a>Preparation

1. Check that your system has `wget` installed:

	```
	$ which wget
	/usr/bin/wget
	```

	If the `which` command does not return a path, you will need to install `wget`:

	```
	$ sudo apt update
	$ sudo apt install -y wget
	```

2. Clone PiBuilder onto your Raspberry Pi:

	```
	$ cd
	$ git clone https://github.com/Paraphraser/PiBuilder.git
	```

	It does not matter whether or not you used PiBuilder to build your Raspberry Pi. The idea here is to make sure you have the latest and greatest version of PiBuilder on your Raspberry Pi. If you *previously* cloned PiBuilder, make sure it is up-to-date:
	
	```
	$ cd ~/PiBuilder
	$ git pull origin master
	```

## <a name="nuclearOption"></a>The nuclear option – getting a clean slate

### <a name="uninstalling"></a>Uninstalling docker, docker-compose

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

	Note:
	
	* It is safe to run both of these `uninstall_` commands even if you are not sure whether docker and docker-compose are installed.

### <a name="reinstalling"></a>Re-installing docker, docker-compose

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

## <a name="upgrading"></a>Upgrading docker, docker-compose

### <a name="upgradeDocker"></a>Upgrading docker

Docker is upgraded via `apt` so you can use the standard system maintenance commands:

```
$ sudo apt update
$ apt list --upgradable
$ sudo apt upgrade
```

Note:

* If an `apt upgrade` installs a new version of `docker`, that *will* restart your stack. That's why the `apt list` command is in the middle - so you can see whether `docker` will be upgraded and decide whether to proceed or defer the upgrade.

### <a name="upgradeCompose"></a>Upgrading docker-compose

You can check the version of docker-compose installed on your system by running either or both of the following commands:

```bash
$ docker-compose version
$ docker compose version
```

The first form follows your PATH variable and executes the first executable file it finds with the name `docker-compose`. The second form uses plugin syntax (likely how "compose" will be invoked in the future).

Both commands should return the same version number. If you spot any discrepancies, you can find out where `docker-compose` is installed on your system by running:

```bash
$ cd ~/PiBuilder/boot/scripts/helpers
$ ./find_docker-compose.sh
```

You can find out if a later version of modern docker-compose is available by visiting the [releases page](https://github.com/docker/compose/releases).

You can upgrade (or downgrade) to a particular version of modern docker-compose like this:

```bash
$ cd ~/PiBuilder/boot/scripts/helpers
$ sudo ./upgrade_docker-compose.sh «version»
```

where:

* «version» is the value on the [releases page](https://github.com/docker/compose/releases) and always starts with a "v". For example:

	```bash
	$ sudo ./upgrade_docker-compose.sh v2.4.1
	```

The `upgrade_docker-compose.sh` script:

1. Checks for the old version of docker-compose installed by `apt`. If it finds that, it gives you instructions on how to proceed but it does not attempt to change your system. This is because you may have to remove and re-install docker, and that is not something you are going to want to do while your stack is running. You will also likely want to take a backup before you start.
2. Checks for and removes the Python version of docker-compose.
3. Checks for and removes other versions of modern docker-compose.
4. Attempts to download and install the requested version of modern docker-compose.

If the download fails (typically because you have asked for a version that does not actually exist - did you forget the "v"?), the script falls back to the Python version of docker-compose.

Note:

* The `upgrade_docker-compose.sh` script is *reasonably* platform-agnostic. It works on Raspberry Pi (Buster and Bullseye) full 32-bit, mixed 32-bit user with 64-bit kernel, and full 64-bit OS. It also appears to work on macOS for Docker Desktop.
