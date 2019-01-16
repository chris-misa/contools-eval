#!/bin/bash

B="----------------"

TARGET_IPV4="10.10.1.2"

PING_ARGS="-D -i 0.0 -s 56"

export BG_PING_ARGS="-i 0.0 -s 56 10.10.1.3"

export NETWORK="bridge"

export MAX_CPU=16

TRACE_CMD_ARGS="-e syscalls:sys_enter_sendto -e net:net_dev_queue -e net:netif_receive_skb -e net:napi_gro_frags_entry -e net:net_dev_start_xmit -e syscalls:sys_exit_recvmsg -M ffff"
TRACE_CMD_CMD="sleep 0.02"

export DOCKER_CPUSET_CMD="$(pwd)/dockercpuset.sh"

CONTAINER_COUNTS=(
# `seq 0 1 100`
1 2 3 4
)

export CONTAINER_PING_CMD="/iputils/ping"

export PING_CONTAINER_IMAGE="chrismisa/contools:ping-ubuntu"
PING_CONTAINER_NAME="ping-container"

COMPOSE_FILE="${HOME}/contools-eval/ping_compose/docker-compose.yml"

PAUSE_CMD="sleep 5"
PING_PAUSE_CMD="sleep 10"

DATE_TAG=`date +%Y%m%d%H%M%S`
META_DATA="Metadata"
MANIFEST="manifest"

mkdir $DATE_TAG
cd $DATE_TAG

# Get some basic meta-data
echo "uname -a -> $(uname -a)" >> $META_DATA
echo "docker -v -> $(docker -v)" >> $META_DATA
echo "lsb_release -a -> $(lsb_release -a)" >> $META_DATA
echo "sudo lshw -> $(sudo lshw)" >> $META_DATA

#
# Container pings
#

for n_containers in ${CONTAINER_COUNTS[@]}; do

	echo $B Container run $B

	# Start ping container as service
	docker-compose -f $COMPOSE_FILE up -d --scale ping=$n_containers

	$DOCKER_CPUSET_CMD
	$PAUSE_CMD

	trace-cmd record $TRACE_CMD_ARGS $TRACE_CMD_CMD
	echo "  traced"

	$PAUSE_CMD

	# Stop the containers
	docker-compose -f $COMPOSE_FILE down
	echo $B Stopped $n_containers containers $B

	trace-cmd report -t > ${n_containers}containers_${TARGET_IPV4}.trace
	echo "${n_containers}containers_${TARGET_IPV4}.trace" >> $MANIFEST
	echo $B Converted trace $B
done

rm trace.dat

echo Done.
