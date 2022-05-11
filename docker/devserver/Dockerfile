# Use current LTS
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND="noninteractive"

RUN apt-get update \
  && apt-get -y install curl git gnupg2 less openjdk-11-jre python3-pip tzdata unzip vim wget \
  && apt-get -y upgrade \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV TRINO_VERSION=380

RUN curl -o /usr/bin/trino-cli https://repo1.maven.org/maven2/io/trino/trino-cli/${TRINO_VERSION}/trino-cli-${TRINO_VERSION}-executable.jar \
  && echo 'trino-cli --server trino --user "${TRINO_USER}" --catalog hive --schema $1' > /usr/bin/trino \
  && chmod +x /usr/bin/trino-cli /usr/bin/trino \
  \
  && pip3 install presto-python-client minio \
  && curl -o /usr/bin/mc https://dl.min.io/client/mc/release/linux-amd64/mc \
  && chmod +x /usr/bin/mc \
  \
  && trino-cli --version \
  && mc --version
