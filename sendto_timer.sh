#!/bin/bash

B="----------------"

TARGET_IPV4="10.10.1.2"

PING_ARGS="-D -i 0.0 -s 56"

export BG_PING_ARGS="-i 0.0 -s 56 10.10.1.3"

# Careful: always change this in docker compose file too!
export NETWORK="bridge"

TRACE_CMD_ARGS="-e syscalls:sys_enter_sendto -e syscalls:sys_exit_sendto"
TRACE_CMD_CMD="sleep 0.05"


CONTAINER_COUNTS=(
`seq 0 1 20`
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
$NATIVE_PING_CMD $PING_ARGS $TARGET_IPV4 \
	> /dev/null &
#  > native_control_${TARGET_IPV4}.ping &
echo "  pinging. . ."

$PAUSE_CMD

PING_PID=`ps -e | grep ping | sed -E 's/ *([0-9]+) .*/\1/'`
echo "  got ping pid: $PING_PID"

$PAUSE_CMD
trace-cmd record -P $PING_PID $TRACE_CMD_ARGS $TRACE_CMD_CMD
echo "  traced"

$PAUSE_CMD

kill -INT $PING_PID
echo "  killed ping"

trace-cmd report -t > native_control_${TARGET_IPV4}.trace
echo "native_control_${TARGET_IPV4}.trace" >> $MANIFEST
echo $B Converted trace $B


$PAUSE_CMD

#
# Container pings
#

for n_containers in ${CONTAINER_COUNTS[@]}; do

	echo $B Container run $B

	# Start ping container as service
	docker-compose -f $COMPOSE_FILE up -d --scale ping=$n_containers
	docker run -itd --name=$PING_CONTAINER_NAME \
		--net=$NETWORK --entrypoint=$CONTAINER_PING_CMD \
		$PING_CONTAINER_IMAGE \
		$PING_ARGS $TARGET_IPV4 \
		> /dev/null

	echo "  pinging. . . "

	$PAUSE_CMD

	#PING_PID=`ps -e | grep ping | sed -E 's/ *([0-9]+) .*/\1/'`
	PING_PID=`docker inspect $PING_CONTAINER_NAME -f '{{.State.Pid}}'`
	echo "  got ping pid: $PING_PID"

	$PAUSE_CMD
	trace-cmd record $TRACE_CMD_ARGS -P $PING_PID $TRACE_CMD_CMD
	echo "  traced"

	$PAUSE_CMD

	# Stop the containers
	docker-compose -f $COMPOSE_FILE down
	docker stop ${PING_CONTAINER_NAME} > /dev/null
	docker rm ${PING_CONTAINER_NAME} > /dev/null
	echo $B Stopped $n_containers containers $B

	trace-cmd report -t > ${n_containers}containers_${TARGET_IPV4}.trace
	echo "${n_containers}containers_${TARGET_IPV4}.trace" >> $MANIFEST
	echo $B Converted trace $B
done

rm trace.dat

echo Done.
