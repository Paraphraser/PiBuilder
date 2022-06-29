
#=======================================================================
#                     PiBuilder additions to .bashrc
#=======================================================================

# source IOTStackAliases if installed
IOTSTACK_ALIASES="$HOME/.local/IOTstackAliases/dot_iotstack_aliases"
[ -f "$IOTSTACK_ALIASES" ] && source "$IOTSTACK_ALIASES"
unset IOTSTACK_ALIASES

# https://www.docker.com/blog/faster-builds-in-compose-thanks-to-buildkit-support/
# https://docs.docker.com/compose/reference/build/#native-build-using-the-docker-cli
# https://docs.docker.com/compose/reference/envvars/#compose_docker_cli_build
# https://docs.docker.com/develop/develop-images/build_enhancements/#to-enable-buildkit-builds
export COMPOSE_DOCKER_CLI_BUILD=1
export DOCKER_BUILDKIT=1

# can be useful if a common docker-compose.yml is shared across multiple
# machines but you only want containers active on particular machines
export COMPOSE_PROFILES=$(hostname -s)
