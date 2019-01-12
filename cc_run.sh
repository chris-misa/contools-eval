#!/bin/bash


# TARGET_IPV4="10.10.1.2"


export NATIVE_PING_CMD="${HOME}/contools-eval/iputils/ping"
export CONTAINER_PING_CMD="/iputils/ping"

export PING_CONTAINER_IMAGE="chrismisa/contools:ping-ubuntu"

PING_CONTAINER_NAME="ping-container"
TARGET_CONTAINER_NAME="target"

COMPOSE_FILE="${HOME}/contools-eval/ping_compose/docker-compose.yml"

PAUSE_CMD="sleep 5"

META_DATA="Metadata"
MANIFEST="manifest"

mkdir ${DATE_TAG}_CC
cd ${DATE_TAG}_CC

# Get some basic meta-data
echo "uname -a -> $(uname -a)" >> $META_DATA
echo "docker -v -> $(docker -v)" >> $META_DATA
echo "lsb_release -a -> $(lsb_release -a)" >> $META_DATA
echo "sudo lshw -> $(sudo lshw)" >> $META_DATA

# Start target container
docker run -itd --net=$NETWORK \
	--name=$TARGET_CONTAINER_NAME \
	--cpuset-cpus=$CPU_LIST \
	ubuntu /bin/bash
TARGET_IPV4=`docker inspect $TARGET_CONTAINER_NAME -f "{{.NetworkSettings.Networks.${NETWORK}.IPAddress}}"`

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

for n_containers in ${CONTAINER_COUNTS}; do

	echo $B Container run $B

	# Start background containers
	docker-compose -f $COMPOSE_FILE up -d --scale ping=$n_containers
	docker run -itd --name=$PING_CONTAINER_NAME \
		--net=$NETWORK --entrypoint=/bin/bash \
		--cpuset-cpus=$CPU_LIST \
		$PING_CONTAINER_IMAGE

	$PAUSE_CMD

	$DOCKERCPUSET_CMD
	
	echo "  assigned CPUs"
	ps -eH -o comm,pid,cpuid > ${n_containers}verify

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

	$PAUSE_CMD
done

docker stop $TARGET_CONTAINER_NAME > /dev/null
docker rm $TARGET_CONTAINER_NAME > /dev/null

echo Done.
