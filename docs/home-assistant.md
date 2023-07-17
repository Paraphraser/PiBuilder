# About Supervised Home Assistant

> The information below has been added to [IOTstack Pull Request 528](https://github.com/SensorsIot/IOTstack/pull/528) and should appear in the IOTstack documentation for Home Assistant once that Pull Request has been approved and applied.

IOTstack used to offer a menu entry leading to a convenience script that could install Supervised Home Assistant. That script stopped working when Home Assistant changed their approach. The script's author [made it clear](https://github.com/Kanga-Who/home-assistant/blob/master/Supervised%20on%20Raspberry%20Pi%20with%20Debian.md) that script's future was bleak so the affordance was [removed from IOTstack](https://github.com/SensorsIot/IOTstack/pull/493).

For a time, you could manually install Supervised Home Assistant using their [installation instructions for advanced users](https://github.com/home-assistant/supervised-installer). Once you got HA working, you could install IOTstack, and the two would (mostly) happily coexist.

The direction being taken by the Home Assistant folks is to supply a [ready-to-run image for your Raspberry Pi](https://www.home-assistant.io/installation/raspberrypi). They still support the installation instructions for advanced users but the [requirements](https://github.com/home-assistant/architecture/blob/master/adr/0014-home-assistant-supervised.md#supported-operating-system-system-dependencies-and-versions) are very specific. In particular:

> Debian Linux Debian 11 aka Bullseye (no derivatives)

Raspberry Pi OS is a Debian *derivative* and it is becoming increasingly clear that the "no derivatives" part of that requirement must be taken literally and seriously. Recent examples of significant incompatibilities include:

* [introducing a dependency on `grub` (GRand Unified Bootloader)](https://github.com/home-assistant/supervised-installer/pull/201). The Raspberry Pi does not use `grub` but the change is actually about forcing Control Groups version 1 when the Raspberry Pi uses version 2.
* [unilaterally starting `systemd-resolved`](https://github.com/home-assistant/supervised-installer/pull/202). This is a DNS resolver which claims port 53. That means you can't run your own DNS service like PiHole, AdGuardHome or BIND9 as an IOTstack container. 

Because of the self-updating nature of Supervised Home Assistant, your Raspberry Pi might be happily running Supervised Home Assistant plus IOTstack one day, and suddenly start misbehaving the next day, simply because Supervised Home Assistant assumed it was in total control of your Raspberry Pi.

If you want Supervised Home Assistant to work, reliably, it really needs to be its own dedicated appliance. If you want IOTstack to work, reliably, it really needs to be kept well away from Supervised Home Assistant. If you want both Supervised Home Assistant and IOTstack, you really need two Raspberry Pis.
