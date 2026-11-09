# Configuring Static IP addressing on Raspbian

## Contents

- [Before you start](#beforeStarting)

- [Bookworm, Trixie and later](#networkManager)

	- [first make DHCP work!](#makeDHCPwork)

	- [helper scripts](#helperScripts)

		- [converting dynamic configurations to static form](#toStatic)

		- [restoring dynamic configuration](#toDynamic)

	- [practical example](#nmExample)

		- [Raspberry Pi is only a DHCP server](#nmDHCPExample)

		- [Raspberry Pi runs its own DNS server](#nmDNSExample)

- [Pre-Bookworm](#nonNetworkManager)

	- [Raspberry Pi runs its own DNS server](#isOwnDNS)

<hr>

<a name="beforeStarting"></a>
## Before you start

Please ask yourself *why* you want to use a static IP address on your Raspberry Pi?

A Raspberry Pi running IOTstack has a *server* role so it definitely needs a *predictable* IP address but, usually, that is best accomplished via a *static binding* in your DHCP server.

> A *static binding* means the DHCP server always assigns the same IP address for a given MAC address (Ethernet or WiFi). It has the same effect as a *static IP address* but all configuration occurs in your DHCP server.

In general, there are only three reasons why a Raspberry Pi would ever need a static IP address hard-coded into the Pi itself:

1. The Raspberry Pi is functioning as a Domain Name System (DNS) server; and/dor
2. The Raspberry Pi is functioning as a Dynamic Host Configuration Protocol (DHCP) server; and/or
3. The Raspberry Pi is functioning as a router.

If you are trying to set up a Raspberry Pi as a router, you will probably be working in `/etc/networks` and you shouldn't be relying upon any information in this document.

So that leaves the situation where you want to set up a DNS or DHCP server. If that is what you are doing, read on. If not, you might find it beneficial to pause for a few moments and reconsider what you are actually trying to achieve.

<a name="networkManager"></a>
## Bookworm, Trixie and later

Beginning with Raspberry Pi OS Bookworm, Network Manager was used to manage network interfaces.

<a name="makeDHCPwork"></a>
### first make DHCP work!

You should first configure your DHCP server such that it allocates to your Raspberry Pi the IP address and other settings that you intend to make static.

> Although the word *should* in the above sentence implies this is optional, it is actually a very strong recommendation. The reason is simple. If your Raspberry Pi ever fails and needs to be re-built, it will acquire the correct settings dynamically ahead of either you or PiBuilder re-applying those settings in static form.

<a name="helperScripts"></a>
### helper scripts

PiBuilder provides two helper scripts:

<a name="toStatic"></a>
#### converting dynamic configurations to static form

Script invocation:

``` console
$ ~/PiBuilder/boot/scripts/helpers/nm_convert_phy_ipv4_to_static.sh «phy»
```

where `«phy»` is the identifier of the network interface, such as `eth0` or `wlan0`. The script sets the following values:

* The IPv4 address of the network interface;
* The IPv4 address of the default gateway on the subnet;
* At least one IPv4 address of a DNS server; and
* At least one DNS search domain.

In an environment which has been configured correctly, all of those will be allocated to each host by DHCP at startup. Running this script simply "snap-freezes" those four dynamic settings into static form.

You can, however, override any or all of those values using the following environment variables:

* `NM_IP_CIDR` is the IPv4 address of the interface in CIDR form. For example:

	``` console
	$ export NM_IP_CIDR="192.128.1.10/24"
	```
		      
* `NM_GATEWAY` is the IPv4 address of the default gateway (router) on the subnet. For example:

	``` console
	$ export NM_GATEWAY="192.168.1.1"
	```
		                   
* `NM_DNS_SERVERS` is the IPv4 address of at least one DNS server. You can include multiple servers using comma-separated notation. Examples:

	``` console
	$ export NM_DNS_SERVERS="192.168.1.1"
	$ export NM_DNS_SERVERS="127.0.0.1,192.168.1.50,8.8.8.8"
	```

* `NM_DNS_DOMAINS` is at least one DNS search domain. You can include multiple search domains using comma-separated notation. Examples:

	``` console
	$ export NM_DNS_DOMAINS="my.home.arpa"
	$ export NM_DNS_DOMAINS="my.home.arpa,your.home.arpa"
	```

<a name="toDynamic"></a>
#### restoring dynamic configuration

Script invocation:

``` console
$ ~/PiBuilder/boot/scripts/helpers/nm_restore_phy_ipv4_to_dynamic.sh «phy»
```

where `«phy»` is the identifier of the network interface, such as `eth0` or `wlan0`.

The script undoes the effect of the earlier script.

<a name="nmExample"></a>
### practical example

The most common situations where you will want to use static, rather than dynamic configurations is where the Raspberry Pi will be functioning as either a DNS server, or a DHCP server, or both.

The reasons are practical. A static IPv4 address is an absolute requirement for a DHCP server (particularly for the primary DHCP server on a subnet). That's because there is a chicken-and-egg problem. The server really needs to know its own IPv4 address ahead of its own DHCP services becoming available.

A static IPv4 address is not an absolute requirement for a DNS server, but you will generally want to customise the order in which DNS queries are resolved, and the most effective way to do that is with a static configuration.

<a name="nmDHCPExample"></a>
#### Raspberry Pi is only a DHCP server

All you have to do is snap-freeze the dynamic configuration:

``` console
$ ~/PiBuilder/boot/scripts/helpers/nm_convert_phy_ipv4_to_static.sh eth0
$ ~/PiBuilder/boot/scripts/helpers/nm_convert_phy_ipv4_to_static.sh wlan0
```

<a name="nmDNSExample"></a>
#### Raspberry Pi runs its own DNS server

In general, a Raspberry Pi that is functioning as a DNS server will want to queries to be resolved in a particular order. The most common pattern is:

1. Consult itself, such as when BIND9 is installed natively or running in a Docker container. If there is no response (eg the Docker container is down), then fail over to,
2. A peer on the same network. It is always a good idea to run DNS servers in pairs. If all local resolution services fail then fail over to,
3. One or more well-known DNS servers, such as those provided by your ISP, Google or CloudFlare.

Example. Suppose you have two Raspberry Pis, offering redundant DNS services:

* Hostname `dns-1`, IP address `192.168.1.50`
* Hostname `dns-2`, IP address `192.168.1.51`

You might condfigure `dns-1` like this:

``` console
$ export NM_DNS_SERVERS="127.0.0.1,192.168.1.51,8.8.8.8"
$ ~/PiBuilder/boot/scripts/helpers/nm_convert_phy_ipv4_to_static.sh eth0
$ ~/PiBuilder/boot/scripts/helpers/nm_convert_phy_ipv4_to_static.sh wlan0
```

In other words, `dns-1` queries itself, then `dns-2`, then 8.8.8.8.

The only change you would make when configuring `dns-2` is to use the IP address of `dns-1` in the first line.

<a name="nonNetworkManager"></a>
## Pre-Bookworm

Assume you want to configure your Raspberry Pi like this:

* The IP address of the Ethernet interface should be 192.168.132.55
* The IP address of the WiFi interface should be 192.168.132.56
* The subnet mask is 255.255.255.0 which, in [CIDR notation](https://en.wikipedia.org/wiki/Classless_Inter-Domain_Routing), is a "/24" network
* The router on the subnet uses the IP address 192.168.132.1
* The router on the subnet is configured to forward any DNS queries to your ISP (this is usually the default).

1. Move to the correct directory:

	``` bash
	$ cd /etc
	```

2. Use `sudo` and the text editor of your choice to edit `dhcpcd.conf` and move to the end of the file. If the file does **not** contain the following line, consider adding it:

	```
	allowinterfaces eth*,wlan*
	```

	What that does is to permit DHCP to be used to discover an IP address for any interface matching those two patterns.  It also has the effect of denying the use of DHCP for interfaces that do not match that pattern. This avoids a problem with the virtual interfaces created by Docker which can hang your Raspberry Pi during reboots if containers were running before the reboot was triggered.

3. At the end of the file, add:

	```
	interface eth0
	static ip_address=192.168.132.55/24
	static routers=192.168.132.1
	static domain_name_servers=192.168.132.1

	interface wlan0
	static ip_address=192.168.132.56/24
	static routers=192.168.132.1
	static domain_name_servers=192.168.132.1
	```

	Notes:

	* If you only want to set a static configuration for one interface, omit the lines for the other interface.
	* The `domain_name_servers` field must point to a functioning DNS server which is capable of handling recursive queries. It can be any of the following:

		- The IP address of your router (eg 192.168.132.1), assuming your router is configured to forward DNS queries to your ISP;
		- The IP address of another host on your local network where a DNS service is running; or
		- The IP address of a well-known DNS service such as 8.8.8.8 (Google).

	* If the Raspberry Pi where you are making these changes will be functioning as its own recursive DNS server then you should consider omitting the `domain_name_servers` entries entirely and following the instructions in [Raspberry Pi runs its own DNS server](#isOwnDNS).

4. Run the following test:

	``` console
	$ grep isc-dhcp-fix.sh /etc/rc.local
	```

	If `grep` returns a hit, it will look something like this:

	```
	/usr/bin/isc-dhcp-fix.sh eth0 wlan0 &
	```

	If your `/etc/rc.local` does indeed contain such a line then you should use `sudo` and your favourite text editor to open `/etc/rc.local` and deactivate that line, as in:

	```
	# /usr/bin/isc-dhcp-fix.sh eth0 wlan0 &
	```

5. Reboot your Raspberry Pi to put your changes into effect.

6. Run the following commands and confirm that the IP addresses assigned to the interfaces reflect your expectations:

	``` bash
	$ ifconfig eth0
	$ ifconfig wlan0
	```

7. Prepare two patches. Of necessity, static IP addresses are host-specific so a host-specific patch is appropriate:

	``` bash
	$ cd /etc
	$ diff dhcpcd.conf.bak dhcpcd.conf >~/dhcpcd.conf.patch@$HOSTNAME
	$ diff rc.local.bak rc.local >~/rc.local.patch@$HOSTNAME
	```

8. Move both patch files to the folder:

	```
	~/PiBuilder/boot/scripts/support/etc/
	```

	The next time you build a Raspberry Pi using PiBuilder, your static IP address configuration will be set automatically.

<a name="isOwnDNS"></a>
### Raspberry Pi runs its own DNS server

A properly functioning DNS service capable of handling recursive queries is critical for any network. If you create your own DNS server **and** it does not function correctly then your Raspberry Pi will not be able to do things like run `apt update; apt upgrade` and will not be able to pull images from DockerHub.

The typical off-the-shelf home router handles this requirement in a transparent fashion. When the router boots and connects to your ISP, it learns the IP addresses of the ISP's recursive DNS servers. As each client device on your LAN boots and makes a DHCP request, the router assigns an IP address and instructs the client to use the router for DNS queries. The router forwards client queries to the ISP's recursive DNS servers.

Key point:

* Ideally, DNS servers operate in pairs, so there is always a fallback.

Assuming your Raspberry Pi is running DNS server software (eg BIND9 or Pi-hole), you can instruct the Pi to use itself for DNS by doing the following:

1. Move into the `/etc` directory:

	``` bash
	$ cd /etc
	```

2. Make a backup copy of the resolver configuration, providing a backup does not exist already:

	``` bash
	$ sudo cp -n resolvconf.conf resolvconf.conf.bak
	```

	> the `-n` means that any existing `.bak` file will not be overwritten.

3. Use `sudo` and your favourite text editor to edit `resolvconf.conf`. Add the following lines to the end of the file:

	```
	name_servers="127.0.0.1 192.168.132.57 8.8.8.8"
	resolv_conf_local_only=NO
	search_domains=your.domain.com
	```

	Interpretation:

	* `name_servers=` is a quoted, ordered list of IP addresses, separated by spaces:

		- `127.0.0.1` means "query **this** host first"; if that fails
		- `192.168.132.57` means "query **another** host"; if that fails
		- `8.8.8.8` means "forward the query to Google's well-known DNS server".

		Above I made the point that DNS servers should operate in pairs. That's the purpose of `192.168.132.57` in this list. It's *another* host under your control that can answer the same queries as *this* host. If you **don't** have a second server then you should omit that IP address and use:

		```
		name_servers="127.0.0.1 8.8.8.8"
		```

		If you **do** have a second DNS server then it should be evident that the two servers need to refer to each other. In other words, when you configure the second DNS server, the second IP address in the list should refer to the first DNS server:

		```
		name_servers="127.0.0.1 192.168.132.55 8.8.8.8"
		```

		You do not have to use `8.8.8.8` as the DNS server of last resort. You can use your ISP's name-servers, or other well-known servers such as Cloudflare's `1.1.1.1`. You are also not limited to just three entries in the list.

	* `resolv_conf_local_only=NO` permits the mixing of the localhost IP address `127.0.0.1` with the other IP addresses in the `name_servers=` list.

	* 	`search_domains=your.domain.com` should be replaced with the domain name for which your Raspberry Pi is authoritative. This feature allows you to use unqualified names like "iot-hub". If an unqualified name does not resolve to a host name then it will be treated as `iot-hub.your.domain.com` and forwarded to your DNS server.

4. Restart the DNS resolver service:

	``` bash
	$ sudo resolvconf -u
	```

5. Prepare a patch file:

	``` bash
	$ diff resolvconf.conf.bak resolvconf.conf >~/resolvconf.conf.patch@$HOSTNAME
	```

6. Copy the patch file from your home directory to your custom clone of PiBuilder and place it in the directory:

	```
	~/PiBuilder/boot/scripts/support/etc/
	```

	On the next build of this host, the changes will be applied automatically.
