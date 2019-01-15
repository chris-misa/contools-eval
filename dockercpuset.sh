#!/bin/bash



# DOCKER_PIDS=$(docker inspect $(docker ps -aq) -f '{{.State.Pid}}')
# for PID in $DOCKER_PIDS; do
# 	taskset --cpu-list -p $CPU_LIST $PID
# done

#
# Distribute container processes among given CPUS
#

DOCKER_PIDS=$(docker inspect $(docker ps -aq) -f '{{.State.Pid}}')
cur_cpu=0
for PID in $DOCKER_PIDS; do
	taskset --cpu-list -p ${cur_cpu}-${cur_cpu} $PID
	cur_cpu=$(( ($cur_cpu + 1) % $MAX_CPU ))
done
