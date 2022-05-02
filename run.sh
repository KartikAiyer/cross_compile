#!/bin/zsh

# This script can be called to run a build/test/command inside the Docker
# build environment container.

# TODO: Currently the host system needs to install qemu-user-static
# or the chroots will fail with an 'Exec format error'. I think this
# means it just can't find qemu-user-static in the path. How can we
# avoid this dependency on the host? Everything should be self-contained
# in the container.
# Looks like this is a kernel issue - the kernel (host and container are
# are shared) does the QEMU binary translating. There are ways to avoid
# this kernel dependency
# see: https://resin.io/blog/building-arm-containers-on-any-x86-machine-even-dockerhub/


set -eEo pipefail
function msg() {
    echo "$*" >&2
}
function err() {
    msg "ERROR: $*"
}
function cleanup() {
    if [[ -v RUN_TMP_DIR && -d ${RUN_TMP_DIR} ]]; then
        rm -rf -- "${RUN_TMP_DIR}"
    fi
}
readonly RUN_TMP_DIR="$(mktemp -d)"
# be extra paranoid and make sure the temp directory exists and is empty since
# we will remove it on exit.
if [[ ! -d ${RUN_TMP_DIR} || -z $(find "${RUN_TMP_DIR}" -maxdepth 0 -empty) ]]; then
    err failed to create temporary directory
    exit 1
fi
trap cleanup EXIT

USAGE="usage: ./run.sh <COMMAND> [notty]"

COMMAND=$1
INTERACTIVE=$2    # Default to on, Set this to "notty" if the host does not provide a TTY (i.e Jenkins)

CUID=${CUID:-$(id -u)}
CGID=${CGID:-$(id -g)}

DOCKER_IMAGE="${COMMAND:l}-run"

# path variables needed early on

# Check that a command was provided
if [[ "$COMMAND" == "" ]]; then
    echo "Argument 1 must be a command"
    echo $USAGE
    exit 1
fi

if [[ "$COMMAND" == "-h" ]]; then
    echo $USAGE
    exit 0
fi

# Get all the actions for a target
if [[ "$COMMAND" == "actions" ]]; then
    ls docker/commands/ | tr '\n' '\0' | xargs -0 -n 1 basename | cut -f 1 -d '.'
    exit 0
fi

# where the image sha256 identifier gets stored by docker build.  refer to the
# docker container using this, rather than a tag, to avoid tag collisions on
# systems with a shared docker cache.
DOCKER_IMAGE_ID_FILE="${RUN_TMP_DIR}/${COMMAND}_docker_image_id"
declare -a DOCKER_BUILD_ARGS=()
DOCKER_BUILD_ARGS+=(--rm)
DOCKER_BUILD_ARGS+=(--iidfile "${DOCKER_IMAGE_ID_FILE}")
# don't tag the docker image in the CI. This will prevent branches using an old
# run.sh script which uses the image tag, rather than the image id, from
# getting the wrong docker image from an updated branch. See HUB-1665
[[ -v CI ]] || DOCKER_BUILD_ARGS+=(-t "${DOCKER_IMAGE}")
DOCKER_BUILD_ARGS+=(--build-arg UID="${CUID}")
DOCKER_BUILD_ARGS+=(--build-arg GID="${CGID}")

echo "${DOCKER_BUILD_ARGS[@]}"

# Make sure the Docker image is built and ready to run commands
echo "Building Docker image..."
# read from stdin to prevent issues where Dockerfile is a symlink
DOCKER_BUILDKIT=1 docker build \
    "${DOCKER_BUILD_ARGS[@]}" -f - docker < "docker/Dockerfile"

if [ $? != 0 ]; then
    echo "ERROR: Failed to build Docker image."
    exit 1
fi

# set up mount paths
MOUNT_PATH="/home/kartik/project"

SCRIPT_PATH="${MOUNT_PATH}/docker/commands/$COMMAND"
SCRIPT_SOURCE="docker/commands/$COMMAND"

# Arguments common to all docker run calls
DOCKER_RUN_ARGS=(
  --rm
  --privileged
)

# Docker volumes to be mounted on all containers
declare -a DOCKER_VOLUMES=()
DOCKER_VOLUMES+=("-v$(pwd):${MOUNT_PATH}")

# Target specifc docker volumes are appended to DOCKER_VOLUMES

# Darwin specific handling of volumes
case "$(uname -s)" in

  Darwin)
    _i_count=${#DOCKER_VOLUMES[@]}
    for ((ii=1;ii<=_i_count;ii++)); do
        DOCKER_VOLUMES[ii]="${DOCKER_VOLUMES[ii]}:delegated"
    done
  ;;

  Linux)
  ;;

  *)
  echo "Unsupported OS: $(uname -s)"
  exit 1
  ;;
esac

declare -a DOCKER_COMMAND=()

if [[ "$COMMAND" = "bash" ]]; then
    # Don't run any build scripts, just open an interactive bash prompt
    # This should rarely be needed - it is here as a convenience
    echo "Opening interactive bash prompt in container"
    DOCKER_VOLUMES+=(-v /dev/bus/usb/:/dev/bus/usb)
    DOCKER_RUN_ARGS+=(-it)
    DOCKER_COMMAND=(bash)
else

    if [[ ! -x ${SCRIPT_SOURCE} ]]; then
      echo "${SCRIPT_SOURCE} does not exist"
      exit 1
    fi
    # Typical builds require fewer privileges
    echo "Running $COMMAND"

    # set up the TTY arg
    if [ "$INTERACTIVE" != "notty" ]; then
      echo "Running with interactive console"
      DOCKER_RUN_ARGS+=("-it")
    fi

    # use the hostname
    DOCKER_RUN_ARGS+=("-h $(hostname)")

    DOCKER_COMMAND=("bash ${SCRIPT_PATH}")
fi
echo "DOCKER VOLUMES: ${DOCKER_VOLUMES}"
echo "${DOCKER_RUN_ARGS}"
echo $(< "${DOCKER_IMAGE_ID_FILE}")
echo "${DOCKER_COMMAND[@]}"
docker run \
    "${DOCKER_VOLUMES[@]}" \
    "${DOCKER_RUN_ARGS[@]}" \
    $(< "${DOCKER_IMAGE_ID_FILE}") \
    "${DOCKER_COMMAND[@]}"

if [ $? != 0 ] && [ "$COMMAND" != "bash" ]; then
    echo "ERROR: Script failed in Docker container."
    exit 1
else
    echo "SUCCESS: Script finished successfully in Docker container."
    exit 0
fi
