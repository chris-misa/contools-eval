#!/bin/bash

B="----------------"

TARGET_IPV4="10.10.1.2"

PING_ARGS="-D -i 0.0 -s 56 -c 500"

# Arguments handed to ping in background containers
export BG_PING_ARGS="-i 0.0 -s 56 $TARGET_IPV4"

export NETWORK="bridge"


CONTAINER_COUNTS=(
# `seq 0 5 20`
0
1
2
3
#   1
#   2
#   3
#   5
#   7
#   11
#   17
#   25
#   38
#   57
#   86
#   129
#   291
#   437
#   656
#   985
#   1477
#   2216
#   3325
#   4987
#   7481
#   11222
#   16834
#   25251
)
# Logarithmic number of containers: [int(1.5 ** x) for x in range(27)]

NATIVE_PING_CMD="${HOME}/contools-eval/iputils/ping"
export CONTAINER_PING_CMD="/iputils/ping"

export PING_CONTAINER_IMAGE="chrismisa/contools:ping-ubuntu"

PING_CONTAINER_NAME="ping-container"

COMPOSE_FILE="${HOME}/contools-eval/ping_compose/docker-compose.yml"

PAUSE_CMD="sleep 5"

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
# Native run
#

echo $B Native control $B

$PAUSE_CMD

# Run ping
echo "  pinging. . ."
echo "native_control_${TARGET_IPV4}.ping" >> $MANIFEST
$NATIVE_PING_CMD $PING_ARGS $TARGET_IPV4 \
  > native_control_${TARGET_IPV4}.ping

$PAUSE_CMD

#
# Container pings
#

for n_containers in ${CONTAINER_COUNTS[@]}; do

	echo $B Container run $B

	# Start background containers
	docker-compose -f $COMPOSE_FILE up -d --scale ping=$n_containers
	docker run -itd --name=$PING_CONTAINER_NAME \
		--net=$NETWORK --entrypoint=/bin/bash \
		$PING_CONTAINER_IMAGE

	$PAUSE_CMD


	echo "${n_containers}containers_${TARGET_IPV4}.ping" >> $MANIFEST
	echo "  pinging. . . "
	docker exec ${PING_CONTAINER_NAME} \
	  $CONTAINER_PING_CMD $PING_ARGS $TARGET_IPV4 \
	  > ${n_containers}containers_${TARGET_IPV4}.ping

	$PAUSE_CMD

	# Stop the containers
	docker stop ${PING_CONTAINER_NAME} > /dev/null
	docker rm ${PING_CONTAINER_NAME} > /dev/null
	docker-compose -f $COMPOSE_FILE down
	echo $B Stopped $n_containers containers $B
done

echo Done.
