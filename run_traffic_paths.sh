#!/bin/bash

B="----------------"

TARGET_IPV4="10.10.1.2"

#PING_ARGS="-D -i 1.0 -s 56"
PING_ARGS="-D -i 0 -s 56 -c 1000"

# Careful: always change this in docker compose file too!
NETWORK="bridge"

NATIVE_PING_CMD="${HOME}/contools-eval/iputils/ping"
CONTAINER_PING_CMD="/iputils/ping"

PING_CONTAINER_IMAGE="chrismisa/contools:ping-ubuntu"
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
# Native run
#

echo $B Native control $B
# Run ping in background
echo "native_control_${TARGET_IPV4}.ping" >> $MANIFEST
echo "  pinging. . ."
$NATIVE_PING_CMD $PING_ARGS $TARGET_IPV4 \
  > native_control_${TARGET_IPV4}.ping

$PAUSE_CMD

#
# Spin up a container
#

docker run -itd --net=$NETWORK \
	--entrypoint=/bin/bash \
	--name=$PING_CONTAINER_NAME \
	$PING_CONTAINER_IMAGE
#
# Local context
#
ping -f $TARGET_IPV4 > /dev/null &

FLOOD_PING_PID=`ps -e | grep ping | sed -E 's/ *([0-9]+) .*/\1/'`

echo $B Local flood ready $B

echo "local_traffic_${TARGET_IPV4}.ping" >> $MANIFEST
docker exec $PING_CONTAINER_NAME \
	$CONTAINER_PING_CMD $PING_ARGS $TARGET_IPV4 \
	> local_traffic_${TARGET_IPV4}.ping


kill -INT $FLOOD_PING_PID
echo "  killed flood ping"


#
# Same container traffic
#
docker exec $PING_CONTAINER_NAME $CONTAINER_PING_CMD -f $TARGET_IPV4 \
	> /dev/null &

$PAUSE_CMD

FLOOD_PING_PID=`ps -e | grep ping | sed -E 's/ *([0-9]+) .*/\1/'`

echo $B Same container flood ready $B

echo "same_container_traffic_${TARGET_IPV4}.ping" >> $MANIFEST
docker exec $PING_CONTAINER_NAME \
	$CONTAINER_PING_CMD $PING_ARGS $TARGET_IPV4 \
	> same_container_traffic_${TARGET_IPV4}.ping

kill -INT $FLOOD_PING_PID
echo "  killed flood ping"


#
# Different container traffic
#
docker run -itd --net=$NETWORK \
	--entrypoint=/bin/bash \
	--name=different-$PING_CONTAINER_NAME \
	$PING_CONTAINER_IMAGE

$PAUSE_CMD

docker exec different-$PING_CONTAINER_NAME $CONTAINER_PING_CMD -f $TARGET_IPV4 \
	> /dev/null &

$PAUSE_CMD

FLOOD_PING_PID=`ps -e | grep ping | sed -E 's/ *([0-9]+) .*/\1/'`

echo $B Different container flood ready $B

echo "different_container_traffic_${TARGET_IPV4}.ping" >> $MANIFEST
docker exec $PING_CONTAINER_NAME \
	$CONTAINER_PING_CMD $PING_ARGS $TARGET_IPV4 \
	> different_container_traffic_${TARGET_IPV4}.ping

kill -INT $FLOOD_PING_PID
echo "  killed flood ping"


docker stop $PING_CONTAINER_NAME > /dev/null
docker stop different-$PING_CONTAINER_NAME > /dev/null
docker rm $PING_CONTAINER_NAME > /dev/null
docker rm different-$PING_CONTAINER_NAME > /dev/null

echo "Done."
