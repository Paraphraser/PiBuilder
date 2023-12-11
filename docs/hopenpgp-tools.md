# About `hopenpgp-tools`

PiBuilder satisfies the dependency requirements listed in the [DrDuh YubiKey Guide](https://github.com/drduh/YubiKey-Guide).

What this means in practice is that any PiBuilder or IOTstack user who has a need to secure any aspect of their IoT operations will find they already have a solid foundation for generating key-pairs, provisioning security keys and/or otherwise employing Public Key Cryptography.

One step in the DrDuh guide recommends validating the generated GnuPG keys using the `lint` command of the `hokey` tool. This is good practice but is, strictly, an *optional* step.

The `hokey` command is installed as part of the `hopenpgp-tools` package.

For reasons that are not clear, the `hopenpgp-tools` has recently become a source of trouble.

With the advent of Debian Bookworm it required the following additional configuration setup for `apt`:

``` console
SOURCE_TARGET="/etc/apt/sources.list"
SOURCE_URL="deb http://ftp.debian.org/debian sid main"
PREF_TARGET="/etc/apt/preferences.d/00-sid"
PREF_CONTENT="$(mktemp -p /dev/shm/)"
cat <<-PREF >"$PREF_CONTENT"
Package: *
Pin: release n=sid
Pin-Priority: 10
PREF

if [ $(grep -c -e "$SOURCE_URL" "$SOURCE_TARGET") -eq 0 ] ; then

	echo "Adding hopenpgp-tools support"
	echo "$SOURCE_URL" | sudo tee -a "$SOURCE_TARGET" >/dev/null
	sudo cp "$PREF_CONTENT" "$PREF_TARGET"
	sudo chmod 644 "$PREF_TARGET"
	sudo apt update

fi
```

after which the package could be installed by running:

```
$ sudo apt install -y hopenpgp-tools
```

Prior to Bookworm, only the `apt install` was needed.

At the time of writing (Dec 11, 2023), that installation strategy also broke. The [status page](https://hackage.haskell.org/package/hopenpgp-tools) reported "DependencyFailed".

Given that the linting operation is not *required* during the generation of GnuPG keys, I have decided to give precedence to *reliability* of of the PiBuilder installation process and remove the dependency.

If you need the `hopenpgp-tools` package then you should:

1. Try the `apt install` command above.
2. If that fails **and** you are running Bookworm then try running the additional configuration setup commands above, and then re-try the `apt install` command.
3. If none of that succeeds then you will just have to wait until the package maintainers solve the problem.
