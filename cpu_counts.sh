#!/bin/bash

export B="----------------"
export C="-+-+-+-+-+-+-+-+"

#export PING_ARGS="-D -i 0.0 -s 56 -c 2000"
export PING_ARGS="-D -i 0.0 -s 56 -c 1000"

# Arguments handed to ping in background containers
export BG_PING_ARGS="-i 0.0 -s 56 10.10.1.3"

export NETWORK="bridge"

export CONTAINER_COUNTS="`seq 0 5 5`"
# export CONTAINER_COUNTS="`seq 0 1 100`"

#export CPU_COUNTS=({0..2})
export CPU_COUNTS=(15)

export DATE_STR=`date +%Y%m%d%H%M%S`

export DOCKERCPUSET_CMD="$(pwd)/dockercpuset.sh"

mkdir $DATE_STR
cd $DATE_STR

for i in ${CPU_COUNTS[@]}; do

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
