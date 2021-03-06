#!/bin/bash

export B="----------------"
export C="-+-+-+-+-+-+-+-+"

#
# Arguments to measurement ping
#

#export PING_ARGS="-D -i 0.0 -s 56 -c 2000"
export PING_ARGS="-D -i 0.0 -s 56 -c 2000"

#
# Sequence of container counts
#

export CONTAINER_COUNTS="`seq 0 10 1000`"
# export CONTAINER_COUNTS="1000"
#
# Array of cpu counts
#

export CPU_COUNTS=(20)

export CONTAINER_NETWORK_TARGET="10.10.1.2"
export CONTAINER_HOST_TARGET="10.10.1.1"

# Arguments handed to ping in traffic containers
export BG_PING_ARGS="-i 0.0 -s 56 10.10.1.3"

# Docker network name to attach everything to
export NETWORK="bridge"

# Path to compose file for generting traffic containers
export COMPOSE_FILE="${HOME}/contools-eval/ping_compose/docker-compose.yml"

# Take date for a (hopefully) unique tage
export DATE_STR=`date +%Y%m%d%H%M%S`

# Command to pin containers to specific cpus
export DOCKERCPUSET_CMD="$(pwd)/pin_all_containers.sh"

# Command to run through list of countainer counts
export RUN_ALL_CMD="$(pwd)/container_steps_run.sh"

# Path to native ping executable
export NATIVE_PING_CMD="${HOME}/contools-eval/iputils/ping"

# Path (in container) to ping executable
export CONTAINER_PING_CMD="/iputils/ping"

# Measurement container image to pull
export PING_CONTAINER_IMAGE="chrismisa/contools:ping-ubuntu"

# Name to keep track of measurement container
export PING_CONTAINER_NAME="ping-container"

# Command to pause script between critical steps
export PAUSE_CMD="sleep 5"

# File names for manifest and metadata files
export META_DATA="Metadata"
export MANIFEST="manifest"

mkdir $DATE_STR
cd $DATE_STR

#
# Loop over different cpu counts
#

for i in ${CPU_COUNTS[@]}; do

	# Used in pin_all_container.sh
	export MAX_CPU=$i

	echo "$C Running on $((MAX_CPU)) CPUS $C"

	export DATE_TAG="${DATE_STR}_$i"

	#echo ${DATE_TAG}_CC >> manifest
	#echo ${DATE_TAG}_CH >> manifest
	echo ${DATE_TAG}_CN >> manifest

	echo "$C Container - Network $C"
	../cn_run.sh

	#echo "$C Container - Host $C"
	#../ch_run.sh

	#echo "$C Container - Container $C"
	#../cc_run.sh
done
