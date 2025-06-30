# Adding a privileged user and disabling root

## Background

The initial state for a newly-installed copy of both macOS and Raspberry Pi OS is:

* The default user (eg `pi` on a Raspberry Pi) is an administrator with the ability to run `sudo`; and
* The root account is disabled.

On macOS, your administrator password is required to use `sudo`. On the Raspberry Pi, `sudo` can be used password-less.

## Debian or Ubuntu installations

When installing Debian and Ubuntu (either natively or as guest systems on Proxmox-VE), the installer gives you a choice:

* If you provide a root password then:

	- the root account will be enabled; and
	- the default user will not be an administrator.

* If you do not provide a root password then:

	- the root account will be disabled; and
	- the default user will be an administrator with the ability to run `sudo` after passing a password challenge (ie like macOS).

The advice given in [Proxmox VE + PiBuilder + IOTstack](./running-on-proxmox-debian.md#noRootPassword) is to **not** provide a root password.

You lose nothing by running with the root account disabled. Any administrator can run commands using `sudo` and, where necessary or convenient, you will still be able to get a root shell using this pattern:

``` console
$ sudo -s
# ... run one or more privileged commands here
# exit
$
```

In words:

1. Get a privileged shell as root. The system prompt changes to `#` to indicate you are running as root.
2. Run as many commands as you need without needing to prefix each one with `sudo`.
3. When you're done, type `exit` or press <kbd>control</kbd>+<kbd>d</kbd>. You are dropped back to the original user and the system prompt changes back to `$` to indicate you are no longer running as root.

## Procedure to add administrator

If you find yourself in the situation where you ignored the advice about not providing a root password at installation time, you change your mind, and you want to avoid a rebuild, you can follow this procedure:

1. Connect to the target host and login as root.

2. Make sure that `sudo` is installed by running:

	``` console
	# apt update && apt install -y sudo
	```

	Notes:

	* The leading `#` does not indicate a comment. It is the system prompt which reminds you that you are running as root.

	* If `sudo` is already installed, this command will do nothing.

3. Define the name of the privileged account you want to create:

	``` console
	# ACCOUNT=«name»
	```

	Account names should start with a lower-case letter. followed by lower-case letters, digits, hyphens or underscores.

4. If the account already exists, skip to step 5. Otherwise, create the account by running:

	``` console
	# adduser --home /home/$ACCOUNT --shell /bin/bash $ACCOUNT
	```

	You will be prompted, twice, for a password. You will also be prompted for other information but it is safe to respond to each prompt by pressing <kbd>return</kbd>.

5. Give the account the ability to run `sudo`:

	``` console
	# usermod -G sudo -a $ACCOUNT
	# usermod -G adm -a $ACCOUNT
	```

6. Test that you can login as that user:

	``` console
	# su - $ACCOUNT
	$
	```

	Notes:

	* Because you are root when you run that command, you will not be prompted for the password for the account.
	* The system prompt will change to `$` indicating you are no longer root.

7. Test that the newly-added user can run commands using `sudo`:

	``` console
	$ sudo echo hello
	```

	You should be prompted for the password for the account.

8. Give the account the ability to run `sudo` **without** being prompted for a password:

	``` console
	$ echo "$USER  ALL=(ALL) NOPASSWD:ALL" | sudo tee "/etc/sudoers.d/$USER"
	```

9. Test that you can execute `sudo` commands **without** being prompted for a password:

	``` console
	$ sudo -K
	$ sudo echo hello
	```

	Notes:

	* When you provided a password to authorise your use of `sudo` in step 7, you were implicitly granted the permission to continue to use `sudo` without facing another password challenge. The implicit permission persists until you logout or a timeout expires, or if you explicitly revoke the permission, which is what `sudo -K` does.

	* Despite the revocation, the second command should still succeed **without** prompting for a password. That's because the account was added to the "sudoers" list in step 8.

10. Drop back to the original root account:

	``` console
	$ exit
	#
	```

	The system prompt changes back to `#` to indicate that you are running as root.

11. Explicitly deny SSH access by root:

	``` console
	# echo "PermitRootLogin no" >/etc/ssh/sshd_config.d/500-root-login.conf
	# systemctl restart ssh
	```

	Notes:

	* In theory, the default for `PermitRootLogin` is `prohibit-password` but experience shows this is not always true. It is safer to set `no` explicitly.
	* If you need to undo this change, delete `500-root-login.conf` and restart SSH.
	* If you try to SSH as root while access is disabled, the behaviour is as though you had entered an incorrect password. You are never told that access by root is disabled.

12. Lock the root account (optional but recommended):

	``` console
	# passwd --lock root
	```

	Locking the account:

	* Prevents use of `su -` or `su - root` to become root;
	* Does not prevent use of `sudo -s` to get a shell as root;
	* Also prevents login via SSH so, technically, you don't need to do step 11 as well.

	Locking leaves the original root password in place but disables it. To re-enable the root account (which, of necessity, you will be doing from the privileged account you created earlier):

	``` console
	$ sudo passwd --unlock root
	```

13. Logout

	``` console
	# exit
	```
