# upgrading a "treeless" Git clone

Between 2023-12-18 and 2026-04-06, PiBuilder cloned the IOTstack, IOTstackAliases and IOTstackBackup from GitHub using this syntax:

``` console
$ git clone --filter=tree:0 «URL» { «destination path» }
```

The `tree:0` filter produces a so-called "treeless clone".

> The use of treeless clones was based on a suggestion made in a comment to [IOTstack PR740](https://github.com/SensorsIot/IOTstack/pull/740). PR740 was a rewrite of the `install.sh` script and a subsequent patch to that PR also implemented the same filter.

At the time, using treeless clones seemed like good advice but it has since been shown to be problematic. Indeed, there are now [strong recommendations](https://github.blog/open-source/git/get-up-to-speed-with-partial-clone-and-shallow-clone/) against treeless clones in other than specific situations (essentially, where the workflow involves clone, use, discard).

As of 2026-04-06, PiBuilder has reverted to making regular clones. That, however, means there may be legacy treeless clones which were created during the intervening period. Treeless clones *mostly* work but they can throw up weird problems once you move outside the box. In particular:

* If Git needs to fetch missing information, it can take an *interminable* time for operations to complete.

	> Although Git really is doing useful work and the command will complete, eventually, the contrast with Git's normal near-instantaneous response time can easily create the impression that it is hung in some kind of loop. If the user gives up and aborts the command, you then have a mess.

* Adding a parallel remote to a treeless clone, and then pulling from that parallel remote, can abort with cryptic errors. Adding a parallel remote is the kind of thing you may want to do to test changes before formalising a pull request.

On balance, these problems are less likely to occur for IOTstackAliases and IOTstackBackup than they are for IOTstack. For that reason, the remainder of this document is dedicated to resolving problems with IOTstack but the same principles apply to the other repositories and, indeed, to treeless clones generally. However, please read [general case](#general-case) before you actually try anything.

PiBuilder includes a script to help convert a treeless clone into a regular clone. The script makes two assumptions:

1. That the treeless clone of IOTstack was created by running:

	``` console
	$ git clone --filter=tree:0 https://github.com/SensorsIot/IOTstack.git ~/IOTstack
	```

	Among other things, that sets up the Git *remote* named "origin" to point to the IOTstack repository on GitHub.

2. That the *remote* named "origin" still exists, and still points to same URL. You can check this by running:

	```
	$ cd ~/IOTstack
	$ git remote -v
	origin	https://github.com/SensorsIot/IOTstack.git (fetch)
	origin	https://github.com/SensorsIot/IOTstack.git (push)
	```
	
	The last two lines are the expected response.

Procedure:

1. Your working directory needs to be that of the treeless clone:

	``` console
	$ cd ~/IOTstack
	```
	
2. Run the script:

	``` console
	$ ~/PiBuilder/boot/scripts/helpers/upgrade_treeless_clone.sh
	```

Git is a complex beast and it is impossible to guarantee a perfect outcome in all possible situations. Absolute worst case is that everything turns to custard.

The simplest approach to solving any problems is to re-clone and perform a manual merge. Something like this will get the job done:

1. Stop your stack:

	``` console
	$ cd ~/IOTstack
	$ docker compose down
	```

2. Move the existing directory out of the way:

	``` console
	$ cd ..
	$ mv IOTstack IOTstack.old
	```

3. Make a brand new clone:

	``` console
	$ git clone https://github.com/SensorsIot/IOTstack.git ./IOTstack
	```

4. Make the **old** directory the working directory:

	``` console
	$ cd IOTstack.old
	```

5. Move relevant files and directories into the new clone. This needs to be done in two stages:

	* Move the files and directories that should **not** need `sudo`:

		``` console 
		$ mv backups services docker-compose*.yml* ../IOTstack
		```
		
		If you encounter permission errors, you should fix those before re-trying the command. The rules are simple:
		
		* `backups/influxdb` and its contents should be owned `root:root`;
		* everything else should be owned by `$USER:$USER`.

	* Move the `volumes` directory, which **does** need `sudo`:

		``` console
		$ sudo mv volumes ../IOTstack
		```

6. Start your stack:

	``` console
	$ cd ../IOTstack
	$ docker compose up -d
	```

7. Once you are happy with the fresh clone, you can clean up:

	```
	$ cd ..
	$ rm -rf IOTstack.old
	```

	It should not be necessary to use `sudo` to remove the `.old` directory but if you run into permission issues, it is acceptable to re-run the command with `sudo`, providing you double-check the command **before** pressing <kbd>return</kbd>.

<a name="general-case"></a>
### general case

Rather than the manual re-clone and merge recommended for IOTstack, you can adopt the approach of making a backup copy of the repo before running `upgrade_treeless_clone.sh`. For example:

``` console
$ cd ~/.local
$ cp -a IOTstackAliases IOTstackAliases.bak
$ cd IOTstackAliases
$ ~/PiBuilder/boot/scripts/helpers/upgrade_treeless_clone.sh
```

Then, if you get a mess, reverting is a matter of:

``` console
$ cd ..
$ rm -rf IOTstackAliases
$ mv IOTstackAliases.bak IOTstackAliases
```

Conversely, if the upgrade script succeeds, clean up by removing the `.bak` directory.
