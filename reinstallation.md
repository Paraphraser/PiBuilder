# Reinstalling docker + docker-compose

A lot of issues raised on [SensorsIot/IOTstack](https://github.com/SensorsIot/IOTstack/issues) amd the [IOTstack Discord channel](https://discord.gg/ZpKHnks) turn out to have improper installation of *docker* and/or *docker-compose* as their underlying cause. The *hows* and *whys* of this happening are not really important. These instructions are intended to help you overcome such problems.

- [General caveat](#caveat)
- [Assumptions](#assumptions)

	- [Assumption 1 – if you didn't use PiBuilder](#assumption1)
	- [Assumption 2 – if you did use PiBuilder](#assumption2)

- [Uninstalling docker, docker-compose and home assistant](#uninstalling)
- [Re-installing docker, docker-compose and home assistant](#reinstalling)

<hr>

## <a name="caveat"> General caveat </a>

It's important to realise that, sometimes, things just get so messed up under the hood of a Raspberry Pi that a complete rebuild is your best solution. If you try these instructions but you still can't resolve the problem, it's likely that a complete rebuild is in your future. That is, of course, PiBuilder's raison d'être.

## <a name="assumptions"> Assumptions </a>

These instructions make two assumptions:

1. Your Raspberry Pi was built using PiBuilder; and
2. The scripts in the version of PiBuilder on your boot partition are up-to-date. 

### <a name="assumption1"> Assumption 1 </a>

If your Raspberry Pi was **not** built using PiBuilder, the `/boot/scripts` folder will not exist. You can satisfy Assumption 1 by running the following commands:

```bash
$ cd
$ wget -q https://codeload.github.com/Paraphraser/PiBuilder/zip/refs/heads/master -O PiBuilder.zip
$ unzip PiBuilder.zip
$ sudo cp -r PiBuilder-master/boot/scripts /boot
$ rm -rf PiBuilder.zip PiBuilder-master
```

In words:

* be in your home directory
* download PiBuilder as a zip
* unpack the zip file (results in a folder named `PiBuilder-master`)
* copy the entire `scripts` structure to your `/boot` partition
* clean up

### <a name="assumption2"> Assumption 2 </a>

If your Raspberry Pi **was** built using PiBuilder, the `/boot/scripts` folder will exist and its contents may have been customised. The safest approach to satisfying Assumption 2 without losing any of your customisations is to proceed like this:

1. Rename the existing `scripts` folder to get it out of the way:

	```bash
	$ sudo mv /boot/scripts /boot/scripts.off
	```

2. Run the commands in [Assumption 1](#assumption1).
3. Perform the [uninstalling](#uninstalling) and [reinstalling](#reinstalling) steps discussed below.
4. Put things back the way they were:

	```bash
	$ sudo rm -rf /boot/scripts
	$ sudo mv /boot/scripts.off /boot/scripts
	```

#### <a name="whyBoot"> *if you're wondering…* </a>

If you're wondering why the scripts need to be on the `/boot` partition, the answer is:

1. The scripts in `/boot/scripts/helpers` do not actually need to be on the `/boot` partition. They can be run from anywhere.
2. Conversely, the `04_setup.sh` script has dependencies on other files and folders that will break if the `/boot/scripts` structure is not intact.

On balance, it just seemed simpler to assume `/boot/scripts` for everything.

## <a name="uninstalling"> Uninstalling – getting a clean slate </a>

1. Is supervised home assistant installed? If it is, run:

	```bash
	$ /boot/scripts/helpers/uninstall_homeassistant-supervised.sh
	$ sudo reboot
	```

	It is safe to run this command even if you are not sure whether supervised home assistant is installed.

2. Is any part of IOTstack running? If yes, run:

	```bash
	$ cd ~/IOTstack
	$ docker-compose down
	```

3. Are any other containers running, such as might have been started with `docker run`? If yes, you need to terminate each one. Here's an example:

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

4. Uninstall docker and docker-compose:

	```bash
	$ /boot/scripts/helpers/uninstall_docker.sh
	$ /boot/scripts/helpers/uninstall_docker-compose.sh
	$ sudo reboot
	```

	It is safe to run both of these `uninstall_` commands even if you are not sure whether docker and docker-compose are installed.

## <a name="reinstalling"> Re-installing docker, docker-compose</a>

PiBuilder's `04_setup.sh` script installs docker and docker-compose, and can install supervised home assistant as an option. You need to make the decision:

* Option 1 - if you **don't** want supervised home assistant to be installed:

	```bash
	$ /boot/scripts/04_setup.sh false
	```

* Option 2 - if you **do** want supervised home assistant to be installed:

	```bash
	$ /boot/scripts/04_setup.sh true
	``` 

It is **not** appropriate to run `04_setup.sh` unless you have just gone through all the steps in [Uninstalling – getting a clean slate](#uninstalling).

The `04_setup.sh` script ends with a reboot. If you passed "true" to then supervised home assistant will start automatically after the reboot. To restart your IOTstack:

```bash
$ cd ~/IOTstack
$ docker-compose up -d
```
