#!/bin/bash

#
# Note: There are several options as to how to distribute containers among
# CPUs. Un-comment one of these.
#

#
# Restrict container processes to run on subset of available CPUs
#

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


#
# Every container process gets four CPUs
#
# 
# DOCKER_PIDS=$(docker inspect $(docker ps -aq) -f '{{.State.Pid}}')
# cur_cpu=0
# for PID in $DOCKER_PIDS; do
# 	next_cpu=$(( $cur_cpu + 1 ))
# 	taskset --cpu-list -p ${cur_cpu}-${next_cpu} $PID
# 	cur_cpu=$(( ($next_cpu + 1) % $MAX_CPU ))
# done
