# Some words about SSH

## About `/etc/ssh`

Whenever you start from a clean Raspberry Pi OS image, the very first boot-up initialises:

```
/etc/ssh
```

The contents of that folder can be thought of as a unique identity for the SSH service on your Raspberry Pi. That "identity" can be captured by: 

```bash
$ cd
$ /boot/scripts/helpers/etc_ssh_backup.sh
```

Suppose your Raspberry Pi has the name "iot-hub". The result of running that script will be:

```
~/etc-ssh-backup.tar.gz@iot-hub
```

If you copy that file into your PiBuilder folder at path:

```
~/PiBuilder/boot/scripts/support/etc/ssh/
```

and then run `setup_boot_volume.sh`, the `etc-ssh-backup.tar.gz@iot-hub` will be copied onto the `boot` volume along with everything else.

When you boot your Raspberry Pi and run:

```bash
$ /boot/scripts/01_setup.sh
``` 

the script will search for `etc-ssh-backup.tar.gz@iot-hub` and, if found, will use it to restore `/etc/ssh` as it was at the time the snapshot was taken. In effect, you have given the machine its original SSH identity.

The contents of `/etc/ssh` are not tied to the physical hardware so if, for example, your "live" Raspberry Pi emits magic smoke and you have to repurpose your "test" Raspberry Pi, you can cause the replacement to take on the SSH identity of the failed hardware.

> Fairly obviously, you will still need to do things like change your DHCP server so that the working hardware gets the IP address(es) of the failed hardware, but the SSH side of things will be in place.

Whether you do this for any or all of your hosts is entirely up to you. I have gone to the trouble of setting up SSH certificates and it is a real pain to have to run around and re-sign the host keys every time I rebuild a Raspberry Pi. It is much easier to set up `/etc/ssh` **once**, then take a snapshot, and re-use the snapshot each time I rebuild.

If you want to learn how to set up password-less SSH access, see [IOTstackBackup SSH tutorial](https://github.com/Paraphraser/IOTstackBackup/blob/master/ssh_tutorial.md). Google is your friend if you want to go the next step and set up SSH certificates.

## About `~/.ssh`

The contents of `~/.ssh` carry the client identity (how «username» authenticates to target hosts), as distinct from the machine identity (how your Raspberry Pi proves itself to clients seeking to connect).

Personally, I use a different approach to maintain and manage `~/.ssh` but it is still perfectly valid to run the supplied:

```bash
$ /boot/scripts/helpers/user_ssh_backup.sh
``` 

and then restore the snapshot in the same way as Script 01 does for `/etc/ssh`. I haven't provided a solution in PiBuilder. You will have to come up with that for yourself.

## Security of snapshots

There is an assumption that it is "hard" for an unauthorised person to gain access to `etc/ssh` and, to a lesser extent, `~/.ssh`. How "hard" that actually is depends on a lot of things, not the least of which is whether you are in the habit of leaving terminal sessions unattended...

Nevertheless, it is important to be aware that the snapshots do contain sufficient information to allow a third party to impersonate your hosts so it is probably worthwhile making some attempt to keep them reasonably secure.

I keep my snapshots on an encrypted volume. You may wish to do the same.
