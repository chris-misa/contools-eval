#!/bin/bash

for n_containers in ${CONTAINER_COUNTS}; do

	echo $B Running for $n_containers containers $B

	# Start background containers
	docker-compose -f $COMPOSE_FILE up -d --scale ping=$n_containers
	docker run -itd --name=$PING_CONTAINER_NAME \
		--net=$NETWORK --entrypoint=/bin/bash \
		$PING_CONTAINER_IMAGE
	echo "  spun up containers"

	$PAUSE_CMD

	$DOCKERCPUSET_CMD
	echo "  assigned CPUs"
	
	$PAUSE_CMD

	echo $B Native run $B

	echo "${n_containers}native_${TARGET_IPV4}.ping" >> $MANIFEST
	echo "  pinging. . ."
	$NATIVE_PING_CMD $PING_ARGS $TARGET_IPV4 \
	  > ${n_containers}native_${TARGET_IPV4}.ping

	$PAUSE_CMD

	echo $B Container run $B

	echo "${n_containers}containers_${TARGET_IPV4}.ping" >> $MANIFEST
	echo "  pinging. . . "
	docker exec ${PING_CONTAINER_NAME} \
	  $CONTAINER_PING_CMD $PING_ARGS $TARGET_IPV4 \
	  > ${n_containers}containers_${TARGET_IPV4}.ping

	$PAUSE_CMD

	# Take verification of cpu assignments
	ps -eH -o comm,pid,cpuid > ${n_containers}verify

	# Stop the containers
	docker stop ${PING_CONTAINER_NAME} > /dev/null
	docker rm ${PING_CONTAINER_NAME} > /dev/null
	docker-compose -f $COMPOSE_FILE down
	echo $B Stopped $n_containers containers $B

	$PAUSE_CMD
done
