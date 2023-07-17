# IOTstack menu maintenance

The change to running the menu in a Python virtual environment seems to be causing some problems. One example is:

```
ModuleNotFoundError: No module named 'virtualenv.activation.xonsh'
```

The IOTstack menu can be a bit of a moving target. Whether the menu works properly or not can depend on:

- how you installed IOTstack:

	- using PiBuilder
	- cloning IOTstack and letting the menu do the work on first launch
	- running IOTstack's [install.sh](https://github.com/SensorsIot/IOTstack/blob/master/install.sh)

- when you first installed IOTstack
- when you last updated your copy of IOTstack
- when you last ran the menu (so that it tried to update its environment).

The recent change to running the menu in a Python virtual environment also appears to be exposing some fundamental incompatibilities of its own.

> The change was part of [Pull Request 560](https://github.com/SensorsIot/IOTstack/pull/560) which was implemented in mid September 2022.

As a workaround, PiBuilder offers a generalised "get out of jail" script. The script tries to reset your Raspberry Pi's Python environment so that it is compatible with [PR560](https://github.com/SensorsIot/IOTstack/pull/560).

## Running the script

Proceed like this:

1. Make sure IOTstack is up-to-date:

	```
	$ cd ~/IOTstack
	$ git pull origin master
	```

	Note:
	
	- if you normally run Old Menu, replace `master` with `old-menu`.

2. Move to your home directory:

	```
	$ cd
	```
	
3. Clone PiBuilder onto your Raspberry Pi:

	```
	$ git clone https://github.com/Paraphraser/PiBuilder.git
	```
	
	It does not matter whether or not you used PiBuilder to build your Raspberry Pi. The idea here is to make sure you have the latest and greatest version of PiBuilder on your Raspberry Pi. If you *previously* cloned PiBuilder as above, make sure it is up-to-date:
		
	```
	$ git -C ~/PiBuilder pull origin master
	```

4. Run the repair script:

	```
	$ ./PiBuilder/boot/scripts/helpers/reset_menu_enviroment.sh
	```

	The script ends with a logout.
	
5. Login again and run the menu:

	```
	$ cd ~/IOTstack
	$ ./menu.sh
	```
	
	The expected output is:
	
	```
	Checking for project update
	From https://github.com/SensorsIot/IOTstack
	 * branch            master     -> FETCH_HEAD
	Project is up to date
	Python virtualenv found.
	Python Version: 'Python 3.9.2'. Python and virtualenv is up to date.
	Please enter sudo pasword if prompted
	Command: docker version -f "{{.Server.Version}}"
	Docker version 20.10.18 >= 18.2.0. Docker is good to go.
	Project dependencies up to date
	
	Existing installation detected.
	Creating python virtualenv for menu...
	Installing menu requirements into the virtualenv...
	```
	
	Notes:
	
	* This is the expected output in the terminal window. You may need to exit the menu before you see all of it.
	* The "Creating python virtualenv" and "Installing menu requirements" processes take time. This only happens the first time the menu is run after a reset so please be patient. Thereafter, the menu launches far more quickly.

## What the script does

1. Calls `apt` to forcibly reinstall up-to-date versions of "python3-pip", "python3-dev" and "python3-virtualenv".
2. Removes both system-wide and user-specific versions of the Python packages "virtualenv", "ruamel.yaml" and "blessed".
3. Installs and/or updates everything mentioned in:

	```
	$HOME/IOTstack/requirements-menu.txt
	```

	This is a user-specific installation. Includes "ruamel.yaml" and "blessed" which previously were installed independently.
4. Protectively removes:

	```
	$HOME/IOTstack/.virtualenv-menu
	```

	That forces the menu to re-initialise the virtual environment on the next run.
	
5. Logs out. This avoids PATH mixups.
