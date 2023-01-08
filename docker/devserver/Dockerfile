# Use current LTS
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND="noninteractive"

RUN apt-get update \
  && apt-get -y install curl git gnupg2 less openjdk-17-jre python3-pip tzdata unzip vim wget \
  && apt-get -y upgrade \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV TRINO_VERSION=405

RUN \
  curl -o /usr/bin/mc https://dl.min.io/client/mc/release/linux-amd64/mc \
  && chmod +x /usr/bin/mc \
  && mc --version \
  \
  && curl -o /usr/bin/trino-cli https://repo1.maven.org/maven2/io/trino/trino-cli/${TRINO_VERSION}/trino-cli-${TRINO_VERSION}-executable.jar \
  && echo 'trino-cli --server trino --user "${TRINO_USER}" --catalog hive --schema $1' > /usr/bin/trino \
  && chmod +x /usr/bin/trino-cli /usr/bin/trino \
  && trino-cli --version \
  \
  && pip3 install minio trino \
  && python3 -c "import minio; print('minio {}'.format(minio.__version__))" \
  && python3 -c "import trino; print('trino {}'.format(trino.__version__))"
