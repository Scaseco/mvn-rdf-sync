#!/bin/bash

##
# Script to watch a set of maven repositories within a given base directory.
# The children of the base directory are typically mounter directories.
# 
# {abs_watch_dir}/{repoName}/{artifactPath}
#

echoerr() { echo "$@" 1>&2; }

SCRIPT_FILE="$(realpath "${BASH_SOURCE:-$0}")"
SCRIPT_DIR="$(dirname "$SCRIPT_FILE")"
echoerr "SCRIPT_DIR=$SCRIPT_DIR"

WATCH_DIR_RAW="$1"
# Normalize watch dir into an absolute path. Also removes trailing slash.
WATCH_DIR="$(cd "$WATCH_DIR_RAW"; pwd)"

if [ -z "$WATCH_DIR" ]; then
  echo "No path to watch specified"
  exit 1
fi

. "$SCRIPT_DIR"/maven-utils.sh
. "$SCRIPT_DIR"/json-utils.sh
# . "$SCRIPT_DIR"/kafka-utils.sh


# Create the topic if it doesn't already exist
"$KAFKA_HOME"/bin/kafka-topics.sh --create --topic "$KAFKA_TOPIC" --bootstrap-server "$KAFKA_BOOTSTRAP_SERVER" || true

inotifywait "$WATCH_DIR" --recursive --monitor --format '%e %w%f' --event CLOSE_WRITE --event DELETE | \
  while read RECORD; do
    EVENT="$(cut -d' ' -f1 <<< "$RECORD")"
    # -f2- outputs all columns starting from the 2nd one
    ABSFILE="$(cut -d' ' -f2- <<< "$RECORD")"

    declare -A map = "$(parse-repo-path "$WATCH_DIR" "$ABSFILE")"    
    PREFIX="${map['prefix']}"
    RELFILE="${map['file']}"

    echo "Change $EVENT in '$RELFILE' (under '$PREFIX')"    
    
    declare -A task
    task['prefix']="$PREFIX"
    task['relFile']="$RELFILE"
    task['event']="$EVENT"
    
    JSONL="$(assoc-to-json "${task[@]}" "jsonl")"
    echo "Publishing event: $JSONL"
    "$KAFKA_HOME"/bin/kafka-console-producer.sh --topic "$KAFKA_TOPIC" --bootstrap-server "$KAFKA_BOOTSTRAP_SERVER" <<< "$JSONL"
    # process-file "$WORK_DIR" "$PREFIX" "$RELFILE" "$EVENT"
  done

