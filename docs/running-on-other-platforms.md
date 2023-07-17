# Running on other platforms

This documents my experience running PiBuilder against an [AMD64](https://www.debian.org/distrib/netinst) image (`.iso` file) of Debian Bullseye under Parallels on an Intel Mac. It may be useful if you are trying to run PiBuilder on:

* hardware that is not a Raspberry Pi; and/or
* an operating system that is not Raspberry Pi OS.

I wanted to mimic *the Raspberry Pi experience* as closely as possible. That implies "headless" connecting only via SSH, with no need for any of the Parallels "integration" such as the ability to drag-and-drop between macOS and the Debian guest system.

To get the OS running, I followed [Installing Debian Linux on your Mac using Parallels Desktop](https://kb.parallels.com/124110), save for the following exceptions:

* At step 6, I chose "Install" rather than "Graphical Install".
* I did not proceed beyond step 10.

I named the system "testbian" and the default user "pi". The installation process also asks for a password for the "root" user, which is needed for the `su` command below.

To complete step 9 of the Parallels process, I used SSH to connect to the guest system from macOS Terminal. That implies the need to accept SSH's TOFU (Trust on First Use) challenge:

``` bash
$ ssh pi@testbian.local
$ su
# apt-get clean
…      other commands from step 9
```

While logged-in as "root", I also took the opportunity to give "pi" the ability to execute `sudo` commands, and then finished with a reboot, which is step 10 of the Parallels instructions:

```
# /sbin/usermod -aG sudo pi
# echo "pi  ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/pi
# /usr/sbin/reboot
```

After the reboot, I reconnected, installed Git, cloned PiBuilder and ran the first script:

``` bash
$ ssh pi@testbian.local
$ sudo apt install -y git
$ git clone https://github.com/Paraphraser/PiBuilder
$ ./PiBuilder/boot/scripts/01_setup.sh 
```

The optional «newhostname» argument to the `01_setup.sh` script is ignored because it depends on `raspi-config` which is not available. The same applies to:

* Pi camera options (`ENABLE_PI_CAMERA`)
* 64-bit kernel option (`PREFER_64BIT_KERNEL`) ; and
* Updating the Raspberry Pi EEPROM.

The remaining scripts can be completed in order, with reboots or logouts at the end of each script:

``` bash
$ ./PiBuilder/boot/scripts/02_setup.sh 
$ ./PiBuilder/boot/scripts/03_setup.sh 
$ ./PiBuilder/boot/scripts/04_setup.sh 
$ ./PiBuilder/boot/scripts/05_setup.sh 
```
 
In the `02_setup.sh` script, the `VM_SWAP` options are ignored.

Compared with a vanilla install of Raspberry Pi OS, I noticed the following omissions from a vanilla install of Debian:

* git (needs to be installed by hand if PiBuilder is to be cloned directly onto the new system)
* rsync (now installed by `01_setup.sh`)
* tree (added to `03_setup.sh`)

There may be others.

Next, I ran `iotstack_restore` to load a backup taken earlier in the day on my "live" Raspberry Pi:

``` bash
$ iotstack_restore 2022-11-23_1100.iot-hub
```

I edited the just-restored `docker-compose.yml` to:

1. Remove all containers except Portainer-CE, Mosquitto, InfluxDB, Node-RED and Grafana. I chose these as the classic MING stack and because, aside from Node-RED mentioned next, there are no hardware dependencies.
2. Deactivate the Node-RED device mappings as follows:

	``` yaml
	x-devices:
	  - "/dev/ttyAMA0:/dev/ttyAMA0"
	  - "/dev/vcio:/dev/vcio"
	  - "/dev/gpiomem:/dev/gpiomem"
	```

	The `x-` prefix deactivates the entire `devices:` clause.

	Note:
	
	* Any container with a `devices:` clause will need similar treatment if the host platform (physical or virtual) does not implement a left-hand-side device.
	* There are pull requests pending for IOTstack which will alert you to devices issues. Many containers with device dependencies will work if are able to supply the relevant `/dev` path on your target system.

3. This MING stack doesn't contain any examples of "privileged" network ports (numbers less than 1024). Those might be a consideration if the host operating system limits access (eg macOS Docker Desktop). 
	
Then I brought up the stack:

1. The images that were pulled (and, in the case of images with an `iotstack-` prefix, augmented locally via Dockerfiles):

	```
	$ docker images
	REPOSITORY               TAG       IMAGE ID       CREATED          SIZE
	iotstack-nodered         latest    3dd2852b8468   10 seconds ago   538MB
	iotstack-mosquitto       latest    aaff81eb15db   52 seconds ago   16.8MB
	grafana/grafana          latest    eb4a939d5821   12 hours ago     342MB
	portainer/portainer-ce   latest    5f11582196a4   2 days ago       287MB
	influxdb                 1.8       064158037146   7 days ago       308MB
	```

2. The architectures associated with those images:

	```
	$ for I in iotstack-nodered iotstack-mosquitto portainer/portainer-ce influxdb:1.8 grafana/grafana ; do echo -n "$I: " ; docker image inspect $I | jq .[0].Architecture ; done
	iotstack-nodered: "amd64"
	iotstack-mosquitto: "amd64"
	portainer/portainer-ce: "amd64"
	influxdb:1.8: "amd64"
	grafana/grafana: "amd64"
	```

3. And, finally, running successfully (ie not in restart loops and, where a container has a health-check script, the script is returning "healthy"):

	```
	$ docker ps
	CONTAINER ID   IMAGE                    COMMAND                  CREATED              STATUS                        PORTS                                                      NAMES
	e1c0ab944e7c   grafana/grafana:latest   "/run.sh"                About a minute ago   Up About a minute (healthy)   0.0.0.0:3000->3000/tcp                                     grafana
	78e47141789f   iotstack-nodered         "./entrypoint.sh"        About a minute ago   Up About a minute (healthy)   0.0.0.0:1880->1880/tcp                                     nodered
	820e15bed543   portainer/portainer-ce   "/portainer"             About a minute ago   Up About a minute             0.0.0.0:8000->8000/tcp, 0.0.0.0:9000->9000/tcp, 9443/tcp   portainer-ce
	addfa7e969b8   iotstack-mosquitto       "/docker-entrypoint.…"   About a minute ago   Up About a minute (healthy)   0.0.0.0:1883->1883/tcp                                     mosquitto
	c2c9340afbc2   influxdb:1.8             "/entrypoint.sh infl…"   About a minute ago   Up About a minute (healthy)   0.0.0.0:8086->8086/tcp                                     influxdb
	```
