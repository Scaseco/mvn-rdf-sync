
export KAFKA_TOPIC_NAME="mvnsync"
export KAFKA_BOOTSTRAP_SERVER="localhost:9092"

create-topic() {
  bin/kafka-topics.sh --create --topic "$KAFKA_TOPIC_NAME" --bootstrap-server "$KAFKA_BOOTSTRAP_SERVER"
}

describe-topic() {
  bin/kafka-topics.sh --describe --topic "$KAFKA_TOPIC_NAME" --bootstrap-server "$KAFKA_BOOTSTRAP_SERVER"
}

publish-event() {
  PAYLOAD="$1"
  bin/kafka-console-producer.sh --topic "$KAFKA_TOPIC_NAME" --bootstrap-server "$KAFKA_BOOTSTRAP_SERVER" <<< "$PAYLOAD"
}


