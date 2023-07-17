# Restoring Buster-style log rotation for syslog

One of the changes introduced by Bullseye affects `/var/log/syslog` rotation:

* Buster rotates the syslog every 24 hours and keeps the current day plus the preceding 7 days (max 8 days).
* Bullseye rotates the syslog every week and keeps the current week plus the preceding 4 weeks (max 35 days).

Whether this is a good thing or not depends on your perspective. For example, you may have a daily cron job which saves "yesterday's" log to another host. If your Pi emits magic smoke, the most you will lose is "today's" log. Bullseye-style rotation implies the potential for losing all logging for "this week". Sure, you can still save "this week's" log every day as it continues to grow but it's less clean.

Anyway, make the assumption that you want to go back to Buster-style log rotation.

To achieve this, you need two things:

1. A copy of `/etc/logrotate.d/rsyslog` from a Bullseye system. This is your baseline.
2. A copy of `/etc/logrotate.d/rsyslog` from a Buster system. This is your target.

Let's assume you have obtained those files and have given them the names:

* `rsyslog.bullseye`
* `rsyslog.buster`

## Procedure

1. Prepare the patch file:

	```
	$ diff rsyslog.bullseye rsyslog.buster >rsyslog.patch
	```

2. Change your working directory:

	```
	$ cd ~/PiBuilder/boot/scripts/support/etc 
	```

3. The relevant directory on the Raspberry Pi is `/etc/logrotate.d`. The `logrotate.d` folder does not exist in PiBuilder so it has to be created:

	```
	$ mkdir logrotate.d
	```

4. Place the `rsyslog.patch` prepared earlier into that directory, so that you wind up with the path:

	```
	~/PiBuilder/boot/scripts/support/etc/logrotate.d/rsyslog.patch
	```

5. By itself, that will not do anything because there is no "hook" in PiBuilder. The next step is to create that. Where you do that is a matter of judgement. In this case, the most appropriate place is the "epilog" for the `05_setup` script. Change your working directory and create an empty placeholder file:

	```
	$ cd ~/PiBuilder/boot/scripts/support/pibuilder/epilogs
	$ touch 05_setup.sh
	```

	Note:

	* the `touch` command does not change the content of any existing file. It is always safe to run this command.

6. Use your favourite text editor to open `05_setup.sh` and add the following lines:

	```
	if is_running_OS_release bullseye ; then
	   try_patch "/etc/logrotate.d/rsyslog" "restore buster behaviour"
	fi
	```

	Note:

	* Both the `is_running_OS_release` and `try_patch` functions are part of PiBuilder.

7. Unfortunately, this creates a problem of its own. `try_patch` calls the `patch` command and a side-effect of the patch command is to create a `.bak` file. In other words, you wind up with:

	```
	/etc/logrotate.d/rsyslog
	/etc/logrotate.d/rsyslog.bak
	```

	The `logrotate` process simply processes everything inside the `logrotate.d` directory. It doesn't ignore the `.bak` file so it winds up rotating the logs twice.

	One possibility is to just remove the `.bak` file after it has been generated:

	```
	if is_running_OS_release bullseye ; then
	   try_patch "/etc/logrotate.d/rsyslog" "restore buster behaviour"
	   sudo rm -f /etc/logrotate.d/rsyslog.bak
	fi
	```

	The general approach of PiBuilder is *auditability* so removing the evidence of patching activity is sub-optimal. It is better to teach `logrotate` to ignore `.bak` files. That involves a second patch.

8. Connect to a Raspberry Pi running Bullseye and change your working directory:

	```
	$ cd /etc
	``` 
   
9. Make a copy of `logrotate.conf` to be your baseline:

	```
	$ sudo cp logrotate.conf logrotate.conf.bak
	```

10. Use `sudo` and your favourite text editor to open `logrotate.conf`.

	* Find the lines:

		```
		# packages drop log rotation information into this directory
		include /etc/logrotate.d
		```
	
	* Before those lines, insert:

		```
		# exclude any files with the .bak extension
		tabooext + .bak
	
		```
	
		> In words: "add `.bak` to the existing list of file extensions that `logrotate` should ignore".
	
	* The final result should look like the [reference version](#logrotateModified)
	* Save your work

11. Prepare a patch file:

	```
	$ diff logrotate.conf.bak logrotate.conf >~/logrotate.conf.patch
	```

12. Move the patch file to the folder:

	```
	~/PiBuilder/boot/scripts/support/etc/
	```

13. Edit the file:

	```
	~/PiBuilder/boot/scripts/support/pibuilder/epilogs/05_setup.sh
	```

	and make its contents look like this:

	```
	if is_running_OS_release bullseye ; then
	   try_patch "/etc/logrotate.conf" "logrotate should ignore .bak"
	   try_patch "/etc/logrotate.d/rsyslog" "restore buster behaviour"
	fi
	```

	The next time you run PiBuilder where the underlying system is Raspbian Bullseye, these two patches will be applied:

	* the `logrotate` process will ignore `.bak` files in `logrotate.d`;
	* the two `.bak` files will be available to prepare new patches if you need to make any further changes; and
	* your system will retain all the evidence of the patching activity.
 
<a name="baselineReference"></a>
## Reference versions of files

At the time of writing (November 2021), these were the baseline versions of `/etc/logrotate.d/rsyslog` on Buster and Bullseye.

<a name="rsyslogBaseline"></a>
### `/etc/logrotate.d/rsyslog`

<a name="rsyslogBuster"></a>
#### Raspbian Buster

```
/var/log/syslog
{
	rotate 7
	daily
	missingok
	notifempty
	delaycompress
	compress
	postrotate
		/usr/lib/rsyslog/rsyslog-rotate
	endscript
}

/var/log/mail.info
/var/log/mail.warn
/var/log/mail.err
/var/log/mail.log
/var/log/daemon.log
/var/log/kern.log
/var/log/auth.log
/var/log/user.log
/var/log/lpr.log
/var/log/cron.log
/var/log/debug
/var/log/messages
{
	rotate 4
	weekly
	missingok
	notifempty
	compress
	delaycompress
	sharedscripts
	postrotate
		/usr/lib/rsyslog/rsyslog-rotate
	endscript
}
```

<a name="rsyslogBullseye"></a>
#### Raspbian Bullseye

```
/var/log/syslog
/var/log/mail.info
/var/log/mail.warn
/var/log/mail.err
/var/log/mail.log
/var/log/daemon.log
/var/log/kern.log
/var/log/auth.log
/var/log/user.log
/var/log/lpr.log
/var/log/cron.log
/var/log/debug
/var/log/messages
{
	rotate 4
	weekly
	missingok
	notifempty
	compress
	delaycompress
	sharedscripts
	postrotate
		/usr/lib/rsyslog/rsyslog-rotate
	endscript
}
```

<a name="rsyslogPatch"></a>
#### `rsyslog.patch`

The result of running:

```
$ diff rsyslog.bullseye rsyslog.buster >rsyslog.patch
$ cat rsyslog.patch
1a2,13
> {
> 	rotate 7
> 	daily
> 	missingok
> 	notifempty
> 	delaycompress
> 	compress
> 	postrotate
> 		/usr/lib/rsyslog/rsyslog-rotate
> 	endscript
> }
> 
```

<a name="logrotateBullseye"></a>
### `/etc/logrotate.conf` - Raspbian Bullseye

<a name="logrotateBaseline"></a>
#### Baseline version - `logrotate.conf.bak`

```
# see "man logrotate" for details

# global options do not affect preceding include directives

# rotate log files weekly
weekly

# keep 4 weeks worth of backlogs
rotate 4

# create new (empty) log files after rotating old ones
create

# use date as a suffix of the rotated file
#dateext

# uncomment this if you want your log files compressed
#compress

# packages drop log rotation information into this directory
include /etc/logrotate.d

# system-specific logs may also be configured here.
```

<a name="logrotateModified"></a>
#### Modified version - `logrotate.conf`

```
# see "man logrotate" for details

# global options do not affect preceding include directives

# rotate log files weekly
weekly

# keep 4 weeks worth of backlogs
rotate 4

# create new (empty) log files after rotating old ones
create

# use date as a suffix of the rotated file
#dateext

# uncomment this if you want your log files compressed
#compress

# exclude any files with the .bak extension
tabooext + .bak

# packages drop log rotation information into this directory
include /etc/logrotate.d

# system-specific logs may also be configured here.
```

<a name="logrotatePatch"></a>
#### `logrotate.conf.patch`

The result of running:

```
$ diff logrotate.conf.bak logrotate.conf > logrotate.conf.patch
$ cat logrotate.conf.patch
19a20,22
> # exclude any files with the .bak extension
> tabooext + .bak
> 
```
