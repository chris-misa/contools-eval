#!/bin/bash

DOCKER_PIDS=$(docker inspect $(docker ps -aq) -f '{{.State.Pid}}')
for PID in $DOCKER_PIDS; do
	taskset --cpu-list -p $CPU_LIST $PID
done
