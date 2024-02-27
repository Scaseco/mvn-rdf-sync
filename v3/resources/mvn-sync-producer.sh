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

to_abs_path() {
  # python -c "import os; print(os.path.abspath('$1'))"
  readlink -f "$1"
}

WATCH_DIR_RAW="$1"
# Normalize watch dir into an absolute path. Also removes trailing slash.

if [ -z "$WATCH_DIR_RAW" ]; then
  echo "No path to watch specified"
  exit 1
fi

WATCH_DIR="$(to_abs_path "$WATCH_DIR_RAW")"
echo "Preparing to watch directory: $WATCH_DIR"

. "$SCRIPT_DIR"/maven-utils.sh
. "$SCRIPT_DIR"/json-utils.sh
# . "$SCRIPT_DIR"/kafka-utils.sh


##
# parse-repo-path outMap WATCH_DIR ABSFILE
#
# Parse the absolute path "ABSFILE" against "WATCH_DIR" into the components
# prefix/file where prefix=watch_dir/reponame
#
parse-repo-path() {
  WATCH_DIR="$1"
  ABSFILE="$2"

  # Cut away the watch dir
  REPOFILE="${ABSFILE#"$WATCH_DIR/"}"

  # Extract the repo folder
  REPONAME="$(cut -d "/" -f1 <<< "$REPOFILE")"
    
  # Cut away the repo folder which leaves us with the relative path to the file
  FILE="${REPOFILE#"$REPONAME/"}"
  
  declare -A amap
  amap['reponame']="$REPONAME"
  amap['prefix']="$WATCH_DIR/$REPONAME/"
  amap['file']="$FILE"
  echo "${amap[@]@K}"
}

# Create the topic if it doesn't already exist
"$KAFKA_HOME"/bin/kafka-topics.sh --create --topic "$KAFKA_TOPIC" --bootstrap-server "$KAFKA_BOOTSTRAP_SERVER" || true

#echo "CLOSE_WRITE,CLOSE /watches/repository/org/aksw/data/gtfsbench/gtfsbench-csv-1-files/0.0.1-SNAPSHOT/_remote.repositories" | \
inotifywait "$WATCH_DIR" --recursive --monitor --format '%e %w%f' --event CLOSE_WRITE --event DELETE | \
  while read RECORD; do
    EVENT="$(cut -d' ' -f1 <<< "$RECORD")"
    # -f2- outputs all columns starting from the 2nd one
    ABSFILE="$(cut -d' ' -f2- <<< "$RECORD")"

    echo "event: $RECORD - $EVENT - $ABSFILE"

    declare -A map="($(parse-repo-path "$WATCH_DIR" "$ABSFILE"))"
    PREFIX="${map['prefix']}"
    RELFILE="${map['file']}"

    echo "Change $EVENT in '$RELFILE' (under '$PREFIX')"    
    
    declare -A task
    task['prefix']="$PREFIX"
    task['relFile']="$RELFILE"
    task['event']="$EVENT"
    
    JSONL="$(assoc-to-json "${task[@]@K}" "jsonl")"
    echo "Publishing event: $JSONL"
    "$KAFKA_HOME"/bin/kafka-console-producer.sh --topic "$KAFKA_TOPIC" --bootstrap-server "$KAFKA_BOOTSTRAP_SERVER" <<< "$JSONL"
    # process-file "$WORK_DIR" "$PREFIX" "$RELFILE" "$EVENT"
  done

