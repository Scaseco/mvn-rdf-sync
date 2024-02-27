#!/bin/bash

# Wrapper for launching docker compose that sets the GROUP_ID and USER_ID variables
# for group id and user id.

echoerr() { echo "$@" 1>&2; }

export USER_HOME="/home/user"
export KAFKA_HOME="$USER_HOME/opt/kafka"
export GROUP_ID=`id -g`
export USER_ID=`id -u`

echoerr "docker-compose environment configured with user-id=$USER_ID and group-id=$GROUP_ID"

VOLUMES_BASE="./volumes"

mkdir -p "$VOLUMES_BASE/zookeeper/1/data"
mkdir -p "$VOLUMES_BASE/zookeeper/1/log"

mkdir -p "$VOLUMES_BASE/kafka/1/data"

mkdir -p "$VOLUMES_BASE/workdir"
mkdir -p "$VOLUMES_BASE/tdb2-data"

docker compose "$@"

