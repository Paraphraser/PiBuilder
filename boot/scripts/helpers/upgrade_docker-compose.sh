#!/usr/bin/env bash

# support user renaming of script
SCRIPT=$(basename "$0")

read -r -d '' COMPOSENOTES <<-EOM
===============================================================================

$SCRIPT is no longer necessary.

The docker "convenience script" now installs both docker and modern
docker-compose. Once installed, both applications are maintained by:

   sudo apt update
   sudo apt upgrade

If you are running this script to try to upgrade docker-compose, the
best thing you can do is follow the instructions in:

   https://github.com/Paraphraser/PiBuilder/blob/master/reinstallation.md

In a nutshell:

   cd
   docker-compose --project-directory ~/IOTstack down
   [ -d ~/PiBuilder ] || git clone https://github.com/Paraphraser/PiBuilder.git
   git -C ~/PiBuilder pull origin master
   ./PiBuilder/boot/scripts/helpers/uninstall_docker.sh
   ./PiBuilder/boot/scripts/helpers/uninstall_docker-compose.sh
   sudo reboot

   # after the reboot
   ./PiBuilder/boot/scripts/04_setup.sh

   # 04_setup.sh ends with a reboot - after the reboot
   docker-compose --project-directory ~/IOTstack up -d

Following this process will ensure both docker and modern docker-compose
are installed correctly. Then, you won't have to take any special action
to keep docker-compose up-to-date.

===============================================================================
EOM

echo "$COMPOSENOTES"
