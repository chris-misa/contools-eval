#!/bin/bash

export B="----------------"
export C="-+-+-+-+-+-+-+-+"

export PING_ARGS="-D -i 1.0 -s 56 -c 30"
#export PING_ARGS="-D -i 0.0 -s 56 -c 100"

# Arguments handed to ping in background containers
export BG_PING_ARGS="-i 0.0 -s 56 10.10.1.3"

export NETWORK="bridge"

export CONTAINER_COUNTS="10"
# export CONTAINER_COUNTS="`seq 0 1 100`"

export DATE_STR=`date +%Y%m%d%H%M%S`

export DOCKERCPUSET_CMD="$(pwd)/dockercpuset.sh"

mkdir $DATE_STR
cd $DATE_STR

for i in {0..3}; do

	echo "$C Running on $i CPUS $C"
	export CPU_LIST="0-$i"

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
