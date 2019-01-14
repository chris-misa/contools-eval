#!/bin/bash

export TARGET_IPV4="10.10.1.2"


export NATIVE_PING_CMD="${HOME}/contools-eval/iputils/ping"
export CONTAINER_PING_CMD="/iputils/ping"

export PING_CONTAINER_IMAGE="chrismisa/contools:ping-ubuntu"

export PING_CONTAINER_NAME="ping-container"

export COMPOSE_FILE="${HOME}/contools-eval/ping_compose/docker-compose.yml"

export PAUSE_CMD="sleep 5"

export META_DATA="Metadata"
export MANIFEST="manifest"

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
