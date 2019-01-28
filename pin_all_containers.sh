#!/bin/bash

#
# Pin all running containers to a specific CPU.
#
# Note: There are several options as to how to distribute containers among
# CPUs. Un-comment one of these.
#

DOCKER_PIDS=$(docker inspect $(docker ps -aq) -f '{{.State.Pid}}')

#
# Restrict all container processes to run on the same subset of available CPUs
#
# Takes CPU_LIST : String of form "<first_cpu>-<last_cpu>" from env
#

# for PID in $DOCKER_PIDS; do
# 	taskset --cpu-list -p $CPU_LIST $PID
# done


#
# Distribute container processes among given CPUS
#
# Takes MAX_CPU : Int from env
#

cur_cpu=0
for PID in $DOCKER_PIDS; do
	taskset --cpu-list -p ${cur_cpu}-${cur_cpu} $PID
	cur_cpu=$(( ($cur_cpu + 1) % $MAX_CPU ))
done


#
# Every container process gets two CPUs
#
# Takes MAX_CPU : Int from env
# 

# cur_cpu=0
# for PID in $DOCKER_PIDS; do
# 	next_cpu=$(( $cur_cpu + 1 ))
# 	taskset --cpu-list -p ${cur_cpu}-${next_cpu} $PID
# 	cur_cpu=$(( ($next_cpu + 1) % $MAX_CPU ))
# done
