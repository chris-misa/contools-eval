#!/bin/bash

#
# Test traffic volume outputed my an increasing number of containers.
#
# The control in this case is processes running natively.
#

export B="----------------"
export C="-+-+-+-+-+-+-+-+"

#
# Arguments to measurement ping
#

export PING_ARGS="-D -i 0.0 -s 56 10.10.1.1"

#
# Sequence of container counts
#

export MIN_CONTAINERS=0
export MAX_CONTAINERS=100
export CONTAINERS_STEP=1

export MAX_CPUS=20

export TARGET_IFACE="ens1f1"

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

# Name to keep track of measurement container
export PING_CONTAINER_NAME="ping-container"

# Command to pause script between critical steps
export PAUSE_CMD="sleep 10"

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

NO_CONTAINERS=$MIN_CONTAINERS
CPU_INDEX=0

echo $C Native run $C

echo $B Getting traffic for $NO_CONTAINERS processes $B

echo ${NO_CONTAINERS}_process_traffic >> $MANIFEST
$GET_TRAFFIC $TARGET_IFACE > ${NO_CONTAINERS}_process_traffic &
TRAFFIC_PID=$!
echo "  Traffic monitor running with pid $TRAFFIC_PID"

$PAUSE_CMD

kill -INT $TRAFFIC_PID

echo $B Done $B

while [[ $NO_CONTAINERS -lt $MAX_CONTAINERS ]]
do

  I=0
  while [[ $I -lt $CONTAINERS_STEP ]]
  do
    # Launch ping process and pin it to CPU_INDEX
    taskset --cpu-list ${CPU_INDEX}-${CPU_INDEX} \
        $NATIVE_PING_CMD $PING_ARGS > /dev/null &
    I=$(( I + 1 ))
    CPU_INDEX=$(( (CPU_INDEX + 1) % MAX_CPUS ))
    NO_CONTAINERS=$(( NO_CONTAINERS + 1 ))
  done

  echo $B Getting traffic for $NO_CONTAINERS processes $B

  echo ${NO_CONTAINERS}_process_traffic >> $MANIFEST
  $GET_TRAFFIC $TARGET_IFACE > ${NO_CONTAINERS}_process_traffic &
  TRAFFIC_PID=$!
  echo "  Traffic monitor running with pid $TRAFFIC_PID"

  $PAUSE_CMD

  kill -INT $TRAFFIC_PID

  echo $B Done $B

done

echo $B Cleaning up $B

pkill ping > /dev/null

echo Cleaned up processes.



NO_CONTAINERS=$MIN_CONTAINERS
CPU_INDEX=0


echo $C Container run $C

echo $B Getting traffic for $NO_CONTAINERS containers $B

echo ${NO_CONTAINERS}_container_traffic >> $MANIFEST
$GET_TRAFFIC $TARGET_IFACE > ${NO_CONTAINERS}_container_traffic &
TRAFFIC_PID=$!
echo "  Traffic monitor running with pid $TRAFFIC_PID"

$PAUSE_CMD

kill -INT $TRAFFIC_PID

echo $B Done $B

while [[ $NO_CONTAINERS -lt $MAX_CONTAINERS ]]
do

  I=0
  while [[ $I -lt $CONTAINERS_STEP ]]
  do
    docker run -itd --name=${PING_CONTAINER_NAME}_$NO_CONTAINERS \
      --net=$NETWORK \
      --cpuset-cpus=${CPU_INDEX}-${CPU_INDEX} \
      $PING_CONTAINER_IMAGE $PING_ARGS > /dev/null
    I=$(( I + 1 ))
    CPU_INDEX=$(( (CPU_INDEX + 1) % MAX_CPUS ))
    NO_CONTAINERS=$(( NO_CONTAINERS + 1 ))
  done

  echo $B Getting traffic for $NO_CONTAINERS containers $B

  echo ${NO_CONTAINERS}_container_traffic >> $MANIFEST
  $GET_TRAFFIC $TARGET_IFACE > ${NO_CONTAINERS}_container_traffic &
  TRAFFIC_PID=$!
  echo "  Traffic monitor running with pid $TRAFFIC_PID"

  $PAUSE_CMD

  kill -INT $TRAFFIC_PID

  echo $B Done $B

done

echo $B Cleaning up $B

$STOP_ALL_CONTAINERS > /dev/null

echo Cleaned up containers



echo Done.
