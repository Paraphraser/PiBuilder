# Configuring Raspbian to use local time-servers

- [The case for using local time-servers](#theCase)
- [Finding your NTP pool servers](#findNTPservers)
- [Configuring Raspbian](#configRPi)
- [Create the patch](#createPatch)

<hr>

<a name="theCase"></a>
## The case for using local time-servers

Out of the box, Raspbian gets its time from NTP servers in the debian.pool.ntp.org domain. You can confirm this via:

```
$ timedatectl show-timesync
...
ServerName=0.debian.pool.ntp.org
...
``` 

Depending on your geographic location, this may not be appropriate. To use a concrete example, query the DNS to obtain some IP addresses for that pool:

```
$ dig @8.8.8.8 0.debian.pool.ntp.org +short
81.166.75.50
176.9.241.107
193.141.27.6
178.17.161.12
```

That returns a randomized list. Ping the first entry:

```
$ ping -c 10 81.166.75.50
PING 81.166.75.50 (81.166.75.50): 56 data bytes
64 bytes from 81.166.75.50: icmp_seq=0 ttl=50 time=316.846 ms
64 bytes from 81.166.75.50: icmp_seq=1 ttl=50 time=316.796 ms
64 bytes from 81.166.75.50: icmp_seq=2 ttl=50 time=317.082 ms
64 bytes from 81.166.75.50: icmp_seq=3 ttl=50 time=316.832 ms
64 bytes from 81.166.75.50: icmp_seq=4 ttl=50 time=316.409 ms
64 bytes from 81.166.75.50: icmp_seq=5 ttl=50 time=317.470 ms
64 bytes from 81.166.75.50: icmp_seq=6 ttl=50 time=316.857 ms
64 bytes from 81.166.75.50: icmp_seq=7 ttl=50 time=316.545 ms
64 bytes from 81.166.75.50: icmp_seq=8 ttl=50 time=316.554 ms
64 bytes from 81.166.75.50: icmp_seq=9 ttl=50 time=317.419 ms

--- 81.166.75.50 ping statistics ---
10 packets transmitted, 10 packets received, 0.0% packet loss
round-trip min/avg/max/stddev = 316.409/316.881/317.470/0.336 ms
```

Very little variance (good) but a 317ms round-trip-time is a fair distance away. Now, let's run the same test for servers which should be closer to my location in Australia:

```
$ dig @8.8.8.8 0.au.pool.ntp.org +short
129.250.35.251
162.159.200.123
129.250.35.250
27.124.125.252

$ ping -c 10 129.250.35.251
PING 129.250.35.251 (129.250.35.251): 56 data bytes
64 bytes from 129.250.35.251: icmp_seq=0 ttl=55 time=17.930 ms
64 bytes from 129.250.35.251: icmp_seq=1 ttl=55 time=17.549 ms
64 bytes from 129.250.35.251: icmp_seq=2 ttl=55 time=17.335 ms
64 bytes from 129.250.35.251: icmp_seq=3 ttl=55 time=17.958 ms
64 bytes from 129.250.35.251: icmp_seq=4 ttl=55 time=17.666 ms
64 bytes from 129.250.35.251: icmp_seq=5 ttl=55 time=17.434 ms
64 bytes from 129.250.35.251: icmp_seq=6 ttl=55 time=17.058 ms
64 bytes from 129.250.35.251: icmp_seq=7 ttl=55 time=17.788 ms
64 bytes from 129.250.35.251: icmp_seq=8 ttl=55 time=17.279 ms
64 bytes from 129.250.35.251: icmp_seq=9 ttl=55 time=16.912 ms

--- 129.250.35.251 ping statistics ---
10 packets transmitted, 10 packets received, 0.0% packet loss
round-trip min/avg/max/stddev = 16.912/17.491/17.958/0.336 ms
```

317ms vs 17ms round-trip times? No contest, really.

<a name="findNTPservers"></a>
## Finding your NTP pool servers

Unless you have good reasons to do otherwise, "your NTP pool servers" generally means "servers in your own country".

Countries usually have several pools and the simplest way to find out what they are is to use Google to conduct a restricted search on your country name like this:

```
«your country name here» site:.pool.ntp.org
```

For Australia, the [answer](https://www.pool.ntp.org/zone/au) is:

```
server 0.au.pool.ntp.org
server 1.au.pool.ntp.org
server 2.au.pool.ntp.org
server 3.au.pool.ntp.org
```

Once you have identified the pool servers for your country, arrange them in space-separated form like this:

```
0.au.pool.ntp.org 1.au.pool.ntp.org 2.au.pool.ntp.org 3.au.pool.ntp.org
```

<a name="configRPi"></a>
## Configuring Raspbian

Login to your Raspberry Pi device. Change your working directory and make a backup of the baseline *timesyncd.conf* file:

```
$ cd /etc/systemd/
$ sudo cp timesyncd.conf timesyncd.conf.bak
```

Use `sudo` and the text editor of your choice to edit `timesyncd.conf`. The baseline file looks like this:

```
#  This file is part of systemd.
#
#  systemd is free software; you can redistribute it and/or modify it
#  under the terms of the GNU Lesser General Public License as published by
#  the Free Software Foundation; either version 2.1 of the License, or
#  (at your option) any later version.
#
# Entries in this file show the compile time defaults.
# You can change settings by editing this file.
# Defaults can be restored by simply deleting this file.
#
# See timesyncd.conf(5) for details.

[Time]
#NTP=
#FallbackNTP=0.debian.pool.ntp.org 1.debian.pool.ntp.org 2.debian.pool.ntp.org 3.debian.pool.ntp.org
#RootDistanceMaxSec=5
#PollIntervalMinSec=32
#PollIntervalMaxSec=2048
```

Find the line beginning with:

```
#NTP=
```

In its commented-out form, this string means Raspbian is using default servers (eg 0.debian.pool.ntp.org).

Change the string to remove the leading \# and append the space-separated list of pool servers you prepared earlier. The result should look like this:

```
NTP=0.au.pool.ntp.org 1.au.pool.ntp.org 2.au.pool.ntp.org 3.au.pool.ntp.org
```

Save the file, then execute these commands:

```
$ sudo timedatectl set-ntp false
$ sudo timedatectl set-ntp true
$ timedatectl show-timesync
```

The confirmation you are looking for in the output from the third command is a line like this:

```
SystemNTPServers=0.au.pool.ntp.org 1.au.pool.ntp.org 2.au.pool.ntp.org 3.au.pool.ntp.org
```

<a name="createPatch"></a>
## Create the patch

1. Prepare the patch file:

	```
	$ cd /etc/systemd/
	$ diff -c timesyncd.conf.bak timesyncd.conf >~/timesyncd.conf.patch
	```
	
	> The `-c` option sets three lines of context and helps the patching system deal with Bullseye/Bookworm differences.

	Example:

	```
	$ cat ~/timesyncd.conf.patch
	*** prx-deb-timesyncd.conf.bak	Wed Aug 30 14:23:11 2023
	--- prx-deb-timesyncd.conf	Wed Aug 30 14:32:37 2023
	***************
	*** 14,19 ****
	--- 14,20 ----
	  
	  [Time]
	  #NTP=
	+ NTP=0.au.pool.ntp.org 1.au.pool.ntp.org 2.au.pool.ntp.org 3.au.pool.ntp.org
	  #FallbackNTP=0.debian.pool.ntp.org 1.debian.pool.ntp.org 2.debian.pool.ntp.org 3.debian.pool.ntp.org
	  #RootDistanceMaxSec=5
	  #PollIntervalMinSec=32
	```

2. Move the patch file to the folder:

	```
	~/PiBuilder/boot/scripts/support/etc/systemd/
	```

	The next time you build a Raspberry Pi using PiBuilder, your time-servers will be set automatically.
