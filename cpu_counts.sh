#!/bin/bash

export B="----------------"
export C="-+-+-+-+-+-+-+-+"

#export PING_ARGS="-D -i 0.0 -s 56 -c 2000"
export PING_ARGS="-D -i 0.0 -s 56 -c 1000"

# Arguments handed to ping in background containers
export BG_PING_ARGS="-i 0.0 -s 56 10.10.1.3"

export NETWORK="bridge"

# export CONTAINER_COUNTS="`seq 0 16 96`"
export CONTAINER_COUNTS="`seq 0 4 100`"
#export CONTAINER_COUNTS="10"

export CPU_COUNTS=(16)
export MEASURE_CPU="0-1"

export DATE_STR=`date +%Y%m%d%H%M%S`

export DOCKERCPUSET_CMD="$(pwd)/dockercpuset.sh"

export RUN_ALL_CMD="$(pwd)/runAllContainerCounts.sh"

mkdir $DATE_STR
cd $DATE_STR

#
# Set up cpuset
#

for i in ${CPU_COUNTS[@]}; do

	export MAX_CPU=$i

	echo "$C Running on $((MAX_CPU)) CPUS $C"

	export DATE_TAG="${DATE_STR}_$i"

	echo ${DATE_TAG}_CC >> manifest
	echo ${DATE_TAG}_CH >> manifest
	echo ${DATE_TAG}_CN >> manifest

	echo "$C Container - Network $C"
	../cn_run.sh

	echo "$C Container - Host $C"
	../ch_run.sh

	echo "$C Container - Container $C"
	../cc_run.sh
done
