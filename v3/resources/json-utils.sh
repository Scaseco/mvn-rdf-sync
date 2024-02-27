#!/bin/bash

##
# Convert a bash map to json.
# assoc-to-json "${assoc[@]@K}" ["jsonl"]
#
# Source: https://stackoverflow.com/a/44792595/160790
#
function assoc-to-json() {
  declare -A amap="($1)"
  format="$2"
  # printf "assoc-to-json called with: %s\n" "${assoc[@]}"

  jqOpts=""
  if [ "$format" = "jsonl" ]; then
    jqOpts="-c"
  fi

  data='{}'
  for i in "${!amap[@]}"; do
    data=$(jq $jqOpts -n \
        --arg data "$data" \
        --arg key "$i"     \
        --arg value "${amap[$i]}" \
        '$data | fromjson + { ($key) : ($value) }')
  done
  echo "$data"
}

function json-to-assoc() {
  JSON="$1"
  declare -A assoc
  while IFS="=" read -r key value; do
    assoc["$key"]="$value"
  done <<< $(jq -r "to_entries|map(\"\(.key)=\(.value)\")|.[]" <<< "$JSON")
  echo "${assoc[@]@K}"
}

function test-json-utils() {
  JSON='{"hello": "world", "bye": "void"}'

  echo "json-to-assoc:"
  tmp="($(json-to-assoc "$JSON"))"
  echo "tmp: $tmp"
  declare -A assoc="$tmp"
  
  echo "assoc-to-json:"
  assoc-to-json "${assoc[@]@K}" "jsonl"
}

