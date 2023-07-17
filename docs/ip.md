# Configuring Static IP addresses on Raspbian

<a name="keyAssumption"></a>
## Critical assumption

This tutorial assumes the Raspberry Pi OS running on your Raspberry Pi was built using PiBuilder. If this assumption holds then:

- the file `/etc/dhcpcd.conf.bak` will exist and its contents will be a copy of `/etc/dhcpcd.conf` as it was in the Raspbian image you downloaded (ie before PiBuilder was run);
- the file `/etc/rc.local.bak` will exist and its contents will be a copy of `/etc/rc.local` as it was in the Raspbian image you downloaded (ie before PiBuilder was run).
 
If this assumption does not hold, this tutorial may not produce the expected results.

If you are unsure about the situation on your Raspberry Pi, you can compare what you see with the [reference versions](#baselineReference).

<a name="staticIP"></a>
## Static IP Address configuration

Assume you want to configure your Raspberry Pi like this:

* The IP address of the Ethernet interface should be 192.168.132.55
* The IP address of the WiFi interface should be 192.168.132.56
* The router on the subnet uses the IP address 192.168.132.1
* The subnet mask is 255.255.255.0 which, in [CIDR notation](https://en.wikipedia.org/wiki/Classless_Inter-Domain_Routing), is a "/24" network
* The Raspberry Pi is also acting as the local domain name server so it is appropriate to set the DNS to use the loopback address 127.0.0.1

1. Move to the correct directory:

	```
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
	static domain_name_servers=127.0.0.1

	interface wlan0
	static ip_address=192.168.132.56/24
	static routers=192.168.132.1
	static domain_name_servers=127.0.0.1
	```

	Note:

	* If you only want to set a static configuration for one interface, omit the lines for the other interface.

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

	```
	$ ifconfig eth0
	$ ifconfig wlan0
	```

7. Prepare two patches. Of necessity, static IP addresses are host-specific so a host-specific patch is appropriate:

	```
	$ cd /etc
	$ diff dhcpcd.conf.bak dhcpcd.conf >~/dhcpcd.conf.patch@$HOSTNAME
	$ diff rc.local.bak rc.local >~/rc.local.patch@$HOSTNAME
	```

8. Move both patch files to the folder:

	```
	~/PiBuilder/boot/scripts/support/etc/
	```

	The next time you build a Raspberry Pi using PiBuilder, your static IP address configuration will be set automatically.

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
