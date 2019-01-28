#!/bin/bash

#
# Script to setup and run container-to-container measurement path
#

TARGET_CONTAINER_NAME="target-container"

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
