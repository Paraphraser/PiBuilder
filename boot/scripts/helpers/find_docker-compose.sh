#!/usr/bin/env bash

# should not run as root
[ "$EUID" -eq 0 ] && echo "This script should NOT be run using sudo" && exit -1

TARGET="docker-compose"

# candidate installation directories
read -r -d '' INSTALL_DIRS <<-EOF
	/usr/local/bin
	/usr/libexec/docker/cli-plugins
	/usr/local/libexec/docker/cli-plugins
	/usr/lib/docker/cli-plugins
	/usr/local/lib/docker/cli-plugins
	/root/.docker/cli-plugins
	$HOME/.docker/cli-plugins
EOF

echo "Candidate installation paths:"

for DIR in $INSTALL_DIRS ; do
  echo -n "- $DIR"
  if [ -e "$DIR" ] ; then
    CANDIDATE="$DIR/$TARGET"
    if [ -e "$CANDIDATE" ] ; then
      echo "/$TARGET is $("$CANDIDATE" version)"
    else
      echo " directory exists but does not contain $TARGET"
    fi
  else
    echo " directory does not exist"
  fi
done
