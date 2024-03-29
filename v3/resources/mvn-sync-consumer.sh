#!/bin/bash

##
# Script to watch a set of maven repositories
# abs_watch_dir/reponame/artifactFile
#

set -o allexport

echoerr() { echo "$@" 1>&2; }

SCRIPT_FILE="$(realpath "${BASH_SOURCE:-$0}")"
SCRIPT_DIR="$(dirname "$SCRIPT_FILE")"
echoerr "SCRIPT_DIR=$SCRIPT_DIR"

WORK_DIR="$1"
SPARQL_ENDPOINT="$2"

if [ -z "$WORK_DIR" ]; then
  echo "No path to work dir specified (this is where meta projects are generated)."
  exit 1
fi

if [ -z "$SPARQL_ENDPOINT" ]; then
  echo "SPARQL endpoint not specified (the one to synchronize with the maven repo)."
  exit 1
fi


. "$SCRIPT_DIR"/shared.sh
. "$SCRIPT_DIR"/maven-utils.sh
. "$SCRIPT_DIR"/json-utils.sh

# . "$SCRIPT_DIR"/kafka-utils.sh

##
# process-file WORK_DIR PREFIX RELFILE EVENT
# 
# PREFIX must end with '/' - it as assumed that ${PREFIX}${RELFILE} forms an absolute path.
#
process-file() {
  WORK_DIR="$1"
  PREFIX="$2"
  RELFILE="$3"
  EVENT="$4"

  echoerr "Detected event $EVENT on file: $RELFILE (under $PREFIX)"

  # Adjust the file pattern: Substitute '|' with '\|'
  FILE_PATTERNX="$(echo "$FILE_PATTERN" | sed "s/|/\\\|/g")"

  # Match dataset artifacts - for those files we instantiate metadata projects
  export IN_TYPE="$(echo "$RELFILE" | sed -nE "s|$FILE_PATTERNX|\1|p")"

  if  [[ "$RELFILE" =~ ^.*-dcat\..*\.*$ && ! -z "$IN_TYPE" ]]; then
    echoerr "Processing as dcat metadata: $RELFILE"
    "$SCRIPT_DIR"/sync-mvn.sh "$PREFIX" "$RELFILE" "$SPARQL_ENDPOINT"
    echoerr "Completed as dcat metadata: $RELFILE"
  elif [ ! -z "$IN_TYPE" -a "$EVENT" != "DELETE" ]; then
    # Note: Deletion of data so far does not trigger removal of metadata
    # Future versions of this script could support options for that

    echoerr "Processing as data artifact: $RELFILE (under $PREFIX)"
    declare -A map="($(parse-maven-path "$RELFILE"))"

    export IN_GROUPID="${map['groupId']}"
    export IN_ARTIFACTID=${map['artifactId']}
    export IN_VERSION="${map['version']}"

    SNAPSHOT=""
    # base version has "-SNAPSHOT" stripped
    BASE_VERSION="${IN_VERSION%%-SNAPSHOT}"
    [[ "$BASE_VERSION" != "$IN_VERSION" ]] && SNAPSHOT="-SNAPSHOT"
    
    export OUT_GROUPID="dcat.${IN_GROUPID}"
    export OUT_ARTIFACTID="$IN_ARTIFACTID"
    # TODO Auto-Increment suffix number based on repository content
    export OUT_VERSION="${BASE_VERSION}-1${SNAPSHOT}"

    OUT_FOLDER="$WORK_DIR/${OUT_GROUPID//.//}/$OUT_ARTIFACTID"
    OUT_FILE="$OUT_FOLDER/pom.xml"

    echoerr "Outfolder: $OUT_FOLDER"

    mkdir -p "$OUT_FOLDER"
    cat "$SCRIPT_DIR/metadata.template.pom.xml" | envsubst '$IN_GROUPID $IN_ARTIFACTID $IN_VERSION $IN_TYPE $OUT_GROUPID $OUT_ARTIFACTID $OUT_VERSION' > "$OUT_FILE"

    (cd "$OUT_FOLDER" && mvn install)
    # (cd "$OUT_FOLDER" && mvn -Prelease deploy -Dmaven.install.skip)

    echoerr "Completed processing as data artifact: $RELFILE (under $PREFIX)"
  fi
}

# Create the topic if it doesn't already exist
# "$KAFKA_HOME"/bin/kafka-topics.sh --create --topic "$KAFKA_TOPIC" --bootstrap-server "$KAFKA_BOOTSTRAP_SERVER" || true

process-record() {
  RECORD="$1"

  echoerr "Received raw record: $RECORD"
  declare -A map="($(json-to-assoc "$RECORD"))"

  PREFIX="${map['prefix']}"
  RELFILE="${map['relFile']}"
  EVENT="${map['event']}"

  echoerr "Change $EVENT in '$RELFILE' (under '$PREFIX')"    
    
  echoerr "Processing: $WORK_DIR $PREFIX $RELFILE $EVENT"
  process-file "$WORK_DIR" "$PREFIX" "$RELFILE" "$EVENT"
}


# https://stackoverflow.com/questions/11003418/calling-shell-functions-with-xargs
"$KAFKA_HOME"/bin/kafka-console-consumer.sh --topic "$KAFKA_TOPIC" --group "$KAFKA_GROUP" --from-beginning --bootstrap-server "$KAFKA_BOOTSTRAP_SERVER" | \
  xargs -P 8 -I {} -d '\n' bash -c 'process-record "$@"' _ {}


#cmd | \
#  while read RECORD; do
#    echo "Received raw record: $RECORD"
#    declare -A map="($(json-to-assoc "$RECORD"))"
#
#    PREFIX="${map['prefix']}"
#    RELFILE="${map['relFile']}"
#    EVENT="${map['event']}"
#
#    echo "Change $EVENT in '$RELFILE' (under '$PREFIX')"    
#    
#    echo "Processing: $WORK_DIR $PREFIX $RELFILE $EVENT"
#    process-file "$WORK_DIR" "$PREFIX" "$RELFILE" "$EVENT"
#  done

