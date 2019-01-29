#!/bin/bash

#
# Script to run container-to-network measurement path
#

export TARGET_IPV4=$CONTAINER_NETWORK_TARGET

mkdir ${DATE_TAG}_CN
cd ${DATE_TAG}_CN

# Get some basic meta-data
echo "uname -a -> $(uname -a)" >> $META_DATA
echo "docker -v -> $(docker -v)" >> $META_DATA
echo "lsb_release -a -> $(lsb_release -a)" >> $META_DATA
echo "sudo lshw -> $(sudo lshw)" >> $META_DATA

#
# Container pings
#
$RUN_ALL_CMD

echo Done.
