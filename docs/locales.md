# Setting localisation options

This is probably the most straightforward patch. The only assumption is that you have not tried to set locales before. In other words, the `/etc/local.gen` file is unchanged from the Raspbian image you downloaded.

## Procedure

1. Be in the correct directory

	```
	$ cd /etc
	```

2. Make a backup copy of the default file:

	```
	$ sudo cp locale.gen locale.gen.bak
	```

3. Launch `raspi-config`

	```
	$ sudo raspi-config
	```

4. Choose your locale options. **Always** include the default "en_GB.UTF-8 UTF-8". For example, I enable:

	* en_AU ISO-8859-1
	* en_AU.UTF-8 UTF-8
	* en_US.UTF-8 UTF-8

	in addition to the default:

	* en_GB.UTF-8 UTF-8

	Those options work for me. You will have to make your own decisions.

5. Follow through to the end of the `raspi-config` process. There is no need to reboot.
6. Prepare a differences file:

	```
	$ diff locale.gen.bak locale.gen >~/locale.gen.patch
	```

	In my case, the patch file looks like this:

	```
	$ cat ~/locale.gen.patch
	134,135c134,135
	< # en_AU ISO-8859-1
	< # en_AU.UTF-8 UTF-8
	---
	> en_AU ISO-8859-1
	> en_AU.UTF-8 UTF-8
	163c163
	< # en_US.UTF-8 UTF-8
	---
	> en_US.UTF-8 UTF-8
	```

7. Move the patch file to the folder:

	```
	~/PiBuilder/boot/scripts/support/etc/
	```

	The next time you build a Raspberry Pi using PiBuilder, your locales will be set automatically.
	
See also the `LOCALE_LANG` environment variable in the PiBuilder options file.

