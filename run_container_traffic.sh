#!/bin/bash

#
# Test effect of container system traffic on RTT directly by using
# a single container running iperf for traffic generation.
#

export B="----------------"

#
# Arguments for ping and iperf
#

export PING_ARGS="-D -i 0.0 -s 56 10.10.1.3 -c 2000"

export NUM_PINGS=5


export TRAFFIC_SETTINGS="10 100 200 300 400 500 600"
export TRAFFIC_UNIT="M" # appended to each element of TRAFFIC_SETTINGS
export TRAFFIC_TARGET="10.10.1.2"

IPERF_ARGS="-P 16 -f m"

export TARGET_IFACE="eno1d1"

# Docker network name to attach everything to
export NETWORK="bridge"

# Take date for a (hopefully) unique tage
export DATE_STR=`date +%Y%m%d%H%M%S`

# Path to traffic collection program
export GET_TRAFFIC="${HOME}/contools-eval/get_net_usage/get_net_usage"

# Path to native ping executable
export NATIVE_PING_CMD="${HOME}/contools-eval/iputils/ping"

# Path to native command to kill all containers
export STOP_ALL_CONTAINERS="${HOME}/contools-eval/stop_all_containers.sh"

# Path (in container) to ping executable
export CONTAINER_PING_CMD="/iputils/ping"

# Measurement container image to pull
export PING_CONTAINER_IMAGE="chrismisa/contools:ping-ubuntu"

# Iperf container image to pull
export IPERF_CONTAINER_IMAGE="chrismisa/contools:iperf"

# Names to keep track of containers
export PING_CONTAINER_NAME="ping-container"
export IPERF_CONTAINER_NAME="iperf-container"

# Command to pause script between critical steps
export PAUSE_CMD="sleep 5"

# File names for manifest and metadata files
export META_DATA="Metadata"
export MANIFEST="manifest"

mkdir $DATE_STR
cd $DATE_STR

# Get some basic meta-data
echo "uname -a -> $(uname -a)" >> $META_DATA
echo "docker -v -> $(docker -v)" >> $META_DATA
echo "lsb_release -a -> $(lsb_release -a)" >> $META_DATA
echo "sudo lshw -> $(sudo lshw)" >> $META_DATA

# Spin up containers in background
docker run -itd --entrypoint=/bin/bash \
	--net=$NETWORK \
	--name=$PING_CONTAINER_NAME \
	$PING_CONTAINER_IMAGE

docker run -itd --entrypoint=/bin/bash \
	--net=$NETWORK \
	--name=$IPERF_CONTAINER_NAME \
	$IPERF_CONTAINER_IMAGE

echo $B Spun up containers $B

for bw in $TRAFFIC_SETTINGS
do
	echo $B Running with ${bw}${TRAFFIC_UNIT} traffic $B

	# Start iperf traffic
	docker exec $IPERF_CONTAINER_NAME \
		iperf -c $TRAFFIC_TARGET $IPERF_ARGS -b ${bw}${TRAFFIC_UNIT} -t 0 \
		> ${bw}${TRAFFIC_UNIT}_traffic.iperf &
	echo ${bw}${TRAFFIC_UNIT}_traffic.iperf >> $MANIFEST
	
	echo "  started traffic"

	$PAUSE_CMD

	# Take RTT measurements
	for i in {1..$NUM_PINGS}
	do
		docker exec $PING_CONTAINER_NAME \
			$CONTAINER_PING_CMD $PING_ARGS \
			>> ${bw}${TRAFFIC_UNIT}_rtt.ping
	done
	echo ${bw}${TRAFFIC_UNIT}_rtt.ping >> $MANIFEST

	echo "  measured rtt"

	$PAUSE_CMD

	# Stop iperf traffic
	pkill iperf

done

docker stop $IPERF_CONTAINER_NAME $PING_CONTAINER_NAME \
	&& docker rm $IPERF_CONTAINER_NAME $PING_CONTAINER_NAME \
	|| echo Failed to get rid of containers.

echo Done.
