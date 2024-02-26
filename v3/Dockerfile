FROM aksw/rpt AS rpt

FROM ubuntu:22.04
MAINTAINER Claus Stadler <cstadler@informatik.uni-leipzig.de>

ENV DEBIAN_FRONTEND noninteractive

# Install packages http://wiki.openstreetmap.org/wiki/Nominatim/Installation#Ubuntu.2FDebian
# Replacements: libgeos-c1 -> libgeos-c1v5

RUN \
    apt-get -y update --fix-missing && \
#    apt-get upgrade -y && \
    apt-get install -y software-properties-common wget git curl sudo inotify-tools xmlstarlet gettext-base lbzip2 bzip2 openjdk-17-jdk maven && \
    apt-get update

RUN echo "29"

# RUN apt-get install -y build-essential libxml2-dev libpq-dev libbz2-dev libtool automake libproj-dev libboost-dev libboost-system-dev libboost-filesystem-dev libboost-thread-dev libexpat-dev gcc proj-bin libgeos-c1v5 libgeos++-dev libexpat-dev php php-pear php-pgsql php-json php-db libapache2-mod-php postgresql postgis postgresql-contrib postgresql-${POSTGRES_VERSION}-postgis-${POSTGIS_VERSION} postgresql-server-dev-${POSTGRES_VERSION} wget

### Set up RPT from the rpt base image ###

COPY --from=rpt /app /rpt

# Adapt the classpath paths to the new location (-i = in place)

RUN sed -i -E 's|(^\|:)/app/|\1/rpt/|g' /rpt/jib-classpath-file
RUN echo 'java -cp @/rpt/jib-classpath-file @/rpt/jib-main-class-file "$@"' > /bin/rpt && chmod +x /bin/rpt

### Switch to local user ###

ARG USER_ID
ARG GROUP_ID
ARG KAFKA_HOME

RUN \
  groupadd -g "${GROUP_ID}" group && \
  useradd -m -u "${USER_ID}" -g "${GROUP_ID}" -s /bin/bash user

USER user
ENV HOME /home/user

### Set up Apache Kafka in user space ###

RUN \
  curl https://downloads.apache.org/kafka/3.6.1/kafka_2.12-3.6.1.tgz --create-dirs -o "${KAFKA_HOME}"/kafka.tgz && \
  tar -xf "${KAFKA_HOME}"/kafka.tgz -C "${KAFKA_HOME}" --strip 1 && \
  rm "${KAFKA_HOME}"/*.tgz

