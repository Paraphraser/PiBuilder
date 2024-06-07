# Configuring Static IP addresses on Raspbian

<a name="keyQuestion"></a>
## Before you start

Please ask yourself *why* you want to use a static IP address on your Raspberry Pi.

A Raspberry Pi running IOTstack has a *server* role so it definitely needs a *predictable* IP address but, usually, that is best accomplished via a *static binding* in your DHCP server.

> A *static binding* means the DHCP server always assigns the same IP address for a given MAC address (Ethernet or WiFi). It has the same effect as a *static IP address* but all configuration occurs in your DHCP server.

In general, there are only two reasons why a Raspberry Pi would ever need a static IP address hard-coded into the Pi itself:

1. The Raspberry Pi is functioning as a Domain Name Server; or
2. The Raspberry Pi is functioning as a router.

If you are trying to set up a Raspberry Pi as a router, you will probably be working in `/etc/networks` and you shouldn't be relying upon any information in this document.

So that leaves the situation where you want to set up a DNS server. If that is what you are doing, read on. If not, you might find it beneficial to pause for a few moments and reconsider what you are actually trying to achieve.

<a name="keyAssumption"></a>
## Critical assumption

This tutorial assumes the Raspberry Pi OS running on your Raspberry Pi was built using PiBuilder. If this assumption holds then:

- the file `/etc/dhcpcd.conf.bak` will exist and its contents will be a copy of `/etc/dhcpcd.conf` as it was in the Raspbian image you downloaded (ie before PiBuilder was run);
- the file `/etc/rc.local.bak` will exist and its contents will be a copy of `/etc/rc.local` as it was in the Raspbian image you downloaded (ie before PiBuilder was run).
 
If this assumption does not hold, this tutorial may not produce the expected results.

If you are unsure about the situation on your Raspberry Pi, you can compare what you see with the [reference versions](#baselineReference).

<a name="staticIP"></a>
## Static IP Address configuration

### when Network Manager is not running

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

2. Use `sudo` and the text editor of your choice to edit `dhcpcd.conf`. The last line in the file should be:

	```
	allowinterfaces eth*,wlan*
	```

	That line, and the four lines preceding it, were added by PiBuilder (see [critical assumption](#keyAssumption)).

3. After the `allowinterfaces` line, insert:

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

	* If the Raspberry Pi where you are making these changes will be functioning as its own recursive Domain Name System server then you should consider omitting the `domain_name_servers` entries entirely and following the instructions in [Raspberry Pi runs its own DNS](#isOwnDNS).

4. PiBuilder also installs:

	```
	/usr/bin/isc-dhcp-fix.sh
	```

	That script may interfere with your static IP address settings. The `isc-dhcp-fix.sh` script is triggered at boot time via the following line which was added to `/etc/rc.local` by PiBuilder (see [critical assumption](#keyAssumption)):

	```
	/usr/bin/isc-dhcp-fix.sh eth0 wlan0 &
	```

	Use `sudo` and your favourite text editor to open `/etc/rc.local`:

	* If you have configured static IP addresses for all active network interfaces, then deactivate the line entirely, as in:

		```
		# /usr/bin/isc-dhcp-fix.sh eth0 wlan0 &
		```

	* If you have configured one interface with a static IP address and you expect the other interface to continue to obtain its IP address dynamically, edit the line to reflect that. For example, if `eth0` is static while `wlan0` is dynamic:

		```
		/usr/bin/isc-dhcp-fix.sh wlan0 &
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

### when Network Manager is running

To set a static IP address on an interface:

1. Get a list of connections:

	``` console
	$ nmcli con show
	NAME                UUID                                  TYPE      DEVICE  
	Wired connection 1  442b8a37-dd73-3593-91c8-2b6dcba56fb3  ethernet  eth0    
	lo                  eb58f55e-c5a5-4736-bb66-b85aada99e62  loopback  lo      
	Macquarie Mesh      352809d3-85e7-4d7f-b8cd-87a55de6b589  wifi      wlan0 
	```  
	
2. Define a variable to hold name of the connection for which you wish to set a static IP address:

	``` console
	$ CONNECTION="Wired connection 1"
	```

3. Use variables to define the critical parameters of the static IP address:

	``` console
	$ ADDRESS=192.168.132.96
	$ PREFIX=24
	$ GATEWAY=192.168.132.1
	```

4. Configure the connection:

	``` console
	$ sudo nmcli con mod "$CONNECTION" \
	       ipv4.addresses "$ADDRESS/$PREFIX" \
	       ipv4.gateway "$GATEWAY" \
	       ipv4.method "manual"
	$ nmcli -g ipv4.method conn show "$CONNECTION"
	$ sudo nmcli conn up "$CONNECTION"
	```
	
Fairly obviously, you don't actually need to use variables. You can just substitute the values into the commands. This structure just makes it clear what needs to go where.

If you want to revert a connection to obtaining its IP address from DHCP then:

``` console
$ sudo nmcli con mod "$CONNECTION" \
       ipv4.addresses "" \
       ipv4.gateway "" \
       ipv4.method "auto"
$ nmcli -g ipv4.method conn show "$CONNECTION"
$ sudo nmcli conn up "$CONNECTION"
```

<a name="isOwnDNS"></a>
## Raspberry Pi runs its own DNS

A properly functioning Domain Name System service capable of handling recursive queries is critical for any network. If you create your own DNS server **and** it does not function correctly then your Raspberry Pi will not be able to do things like run `apt update; apt upgrade` and will not be able to pull images from DockerHub.

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

<a name="baselineReference"></a>
## Reference versions of files

### `/etc/dhcpcd.conf` - baseline

This is the baseline version of `/etc/dhcpcd.conf`. As of the time of writing (November 2021) it is the same for Raspbian Buster and Bullseye.

```
# A sample configuration for dhcpcd.
# See dhcpcd.conf(5) for details.

# Allow users of this group to interact with dhcpcd via the control socket.
#controlgroup wheel

# Inform the DHCP server of our hostname for DDNS.
hostname

# Use the hardware address of the interface for the Client ID.
clientid
# or
# Use the same DUID + IAID as set in DHCPv6 for DHCPv4 ClientID as per RFC4361.
# Some non-RFC compliant DHCP servers do not reply with this set.
# In this case, comment out duid and enable clientid above.
#duid

# Persist interface configuration when dhcpcd exits.
persistent

# Rapid commit support.
# Safe to enable by default because it requires the equivalent option set
# on the server to actually work.
option rapid_commit

# A list of options to request from the DHCP server.
option domain_name_servers, domain_name, domain_search, host_name
option classless_static_routes
# Respect the network MTU. This is applied to DHCP routes.
option interface_mtu

# Most distributions have NTP support.
#option ntp_servers

# A ServerID is required by RFC2131.
require dhcp_server_identifier

# Generate SLAAC address using the Hardware Address of the interface
#slaac hwaddr
# OR generate Stable Private IPv6 Addresses based from the DUID
slaac private

# Example static IP configuration:
#interface eth0
#static ip_address=192.168.0.10/24
#static ip6_address=fd51:42f8:caae:d92e::ff/64
#static routers=192.168.0.1
#static domain_name_servers=192.168.0.1 8.8.8.8 fd51:42f8:caae:d92e::1

# It is possible to fall back to a static IP if DHCP fails:
# define static profile
#profile static_eth0
#static ip_address=192.168.1.23/24
#static routers=192.168.1.1
#static domain_name_servers=192.168.1.1

# fallback to static profile on eth0
#interface eth0
#fallback static_eth0
```

### `/etc/dhcpcd.conf` - with default PiBuilder patch

The default PiBuilder patch adds five lines to the end of the baseline file. The last part of the patched version of the file looks like this:

```
…
# fallback to static profile on eth0
#interface eth0
#fallback static_eth0

# patch needed for IOTstack - stops RPi freezing during boot.
# see https://github.com/SensorsIot/IOTstack/issues/219
# see https://github.com/SensorsIot/IOTstack/issues/253
allowinterfaces eth*,wlan*
```

### `/etc/rc.local` - baseline

This is the baseline version of `/etc/rc.local`. As of the time of writing (November 2021) it is the same for Raspbian Buster and Bullseye.

```
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

# Print the IP address
_IP=$(hostname -I) || true
if [ "$_IP" ]; then
  printf "My IP address is %s\n" "$_IP"
fi

exit 0
```

### `/etc/rc.local` - with default PiBuilder patch

The default PiBuilder patch adds five lines to the middle of the baseline file. The middle part of the patched version of the file looks like this:

```
…
# By default this script does nothing.

logger "EVENT MARK - running /etc/rc.local"

/usr/bin/isc-dhcp-fix.sh eth0 wlan0 &

# Print the IP address
…
```

Note:

* You may have edited the `isc-dhcp-fix.sh` line to change which interfaces are kept alive. For the purposes of preparing patches, any edits you make to *active* files are not important. The only thing that matters is the *baseline* version.
