#!/bin/bash

export B="----------------"

#export PING_ARGS="-D -i 0.0 -s 56 -c 2000"
export PING_ARGS="-D -i 0.0 -s 56 -c 100"

# Arguments handed to ping in background containers
export BG_PING_ARGS="-i 0.0 -s 56 10.10.1.3"

export NETWORK="bridge"

export CONTAINER_COUNTS="10"
export DATE_TAG=`date +%Y%m%d%H%M%S`
# export CONTAINER_COUNTS="`seq 0 1 100`"

export CPU_LIST="0-15"

export DOCKERCPUSET_CMD="$(pwd)/dockercpuset.sh"

./cn_run.sh

./ch_run.sh

./cc_run.sh
