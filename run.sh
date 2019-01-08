#!/bin/bash

B="----------------"

TARGET_IPV4="10.10.1.2"

PING_ARGS="-D -i 1.0 -s 56"

NETWORK="ovsnet"

CONTAINER_COUNTS=(
`seq 10 10 30`
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
CONTAINER_PING_CMD="/iputils/ping"

PING_CONTAINER_IMAGE="chrismisa/contools:ping-ubuntu"
PING_CONTAINER_NAME="ping-container"

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
$NATIVE_PING_CMD $PING_ARGS $TARGET_IPV4 \
  > native_control_${TARGET_IPV4}.ping &
echo "  pinging. . ."

$PAUSE_CMD

PING_PID=`ps -e | grep ping | sed -E 's/ *([0-9]+) .*/\1/'`
echo "  got ping pid: $PING_PID"

$PING_PAUSE_CMD

kill -INT $PING_PID
echo "  killed ping"

$PAUSE_CMD

#
# Container pings
#

for n_containers in ${CONTAINER_COUNTS[@]}; do

	echo $B Container run $B

	# Start ping container as service
	i=1
	while [ "$i" -le "$n_containers" ]; do
		docker run -itd \
		  --name=${PING_CONTAINER_NAME}${i} \
		  --entrypoint=/bin/bash \
		  --net=$NETWORK \
		  $PING_CONTAINER_IMAGE > /dev/null
		i=$(($i + 1))
	done
	echo $B Started $n_containers containers $B

	$PAUSE_CMD


	echo "${n_containers}containers_${TARGET_IPV4}.ping" >> $MANIFEST
	docker exec ${PING_CONTAINER_NAME}1 \
	  $CONTAINER_PING_CMD $PING_ARGS $TARGET_IPV4 \
	  > ${n_containers}containers_${TARGET_IPV4}.ping &
	echo "  pinging. . . "

	$PAUSE_CMD

	PING_PID=`ps -e | grep ping | sed -E 's/ *([0-9]+) .*/\1/'`
	echo "  got ping pid: $PING_PID"

	$PING_PAUSE_CMD

	kill -INT $PING_PID
	echo "  killed ping"

	$PAUSE_CMD

	# Stop the containers
	i=1
	while [ "$i" -le "$n_containers" ]; do
		docker stop ${PING_CONTAINER_NAME}${i} > /dev/null
		docker rm ${PING_CONTAINER_NAME}${i} > /dev/null
		i=$(($i + 1))
	done
	echo $B Stopped $n_containers containers $B
done

echo Done.
