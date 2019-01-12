#!/bin/bash

export B="----------------"

export PING_ARGS="-D -i 0.0 -s 56 -c 2000"
#export PING_ARGS="-D -i 0.0 -s 56 -c 100"

# Arguments handed to ping in background containers
export BG_PING_ARGS="-i 0.0 -s 56 10.10.1.3"

export NETWORK="bridge"

export CONTAINER_COUNTS="10"
# export CONTAINER_COUNTS="`seq 0 1 100`"

export DATE_STR=`date +%Y%m%d%H%M%S`

mkdir $DATE_STR
cd $DATE_STR

for i in {0..15}; do

	export DATE_TAG="${DATE_STR}_$i"

	echo ${DATE_TAG}_CC >> ${DATE_STR}/manifest
	echo ${DATE_TAG}_CH >> ${DATE_STR}/manifest
	echo ${DATE_TAG}_CN >> ${DATE_STR}/manifest

	taskset --cpu-list 0-$i ../cn_run.sh

	taskset --cpu-list 0-$i ../ch_run.sh

	taskset --cpu-list 0-$i ../cc_run.sh
done
