#!/bin/bash


# TARGET_IPV4="10.10.1.2"


export NATIVE_PING_CMD="${HOME}/contools-eval/iputils/ping"
export CONTAINER_PING_CMD="/iputils/ping"

export PING_CONTAINER_IMAGE="chrismisa/contools:ping-ubuntu"

export PING_CONTAINER_NAME="ping-container"
export TARGET_CONTAINER_NAME="target"

export COMPOSE_FILE="${HOME}/contools-eval/ping_compose/docker-compose.yml"

export PAUSE_CMD="sleep 5"

export META_DATA="Metadata"
export MANIFEST="manifest"

mkdir ${DATE_TAG}_CC
cd ${DATE_TAG}_CC

# Get some basic meta-data
echo "uname -a -> $(uname -a)" >> $META_DATA
echo "docker -v -> $(docker -v)" >> $META_DATA
echo "lsb_release -a -> $(lsb_release -a)" >> $META_DATA
echo "sudo lshw -> $(sudo lshw)" >> $META_DATA

# Start target container
docker run -itd --net=$NETWORK \
	--name=$TARGET_CONTAINER_NAME \
	--cpuset-cpus=$CPU_LIST \
	ubuntu /bin/bash
export TARGET_IPV4=`docker inspect $TARGET_CONTAINER_NAME -f "{{.NetworkSettings.Networks.${NETWORK}.IPAddress}}"`


#
# Go through all requested container counts
#

$RUN_ALL_CMD

docker stop $TARGET_CONTAINER_NAME > /dev/null
docker rm $TARGET_CONTAINER_NAME > /dev/null

echo Done.
