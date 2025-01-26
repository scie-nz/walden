# - Trino wants java 23: https://trino.io/docs/current/installation/deployment.html
# - Ubuntu only has openjdk-23-jre in 24.10+ (not in 24.04LTS): https://packages.ubuntu.com/search?keywords=openjdk-23-jre&searchon=names&suite=all&section=all
# So we go with 24.10:
FROM ubuntu:24.10

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get -y install curl git gnupg2 less openjdk-23-jre python3-pip tzdata unzip vim wget \
  && apt-get -y upgrade \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV TRINO_VERSION=468 \
  TRINO_PY_VERSION=0.332.0 \
  MINIO_VERSION=RELEASE.2025-01-17T23-25-50Z \
  MINIO_PY_VERSION=7.2.15

RUN \
  curl -o /usr/bin/mc https://dl.min.io/client/mc/release/linux-amd64/archive/mc.${MINIO_VERSION} \
  && chmod +x /usr/bin/mc \
  && mc --version \
  \
  && curl -o /usr/bin/trino-cli https://repo1.maven.org/maven2/io/trino/trino-cli/${TRINO_VERSION}/trino-cli-${TRINO_VERSION}-executable.jar \
  && echo 'trino-cli --server trino --user "${TRINO_USER}" --catalog hive --schema $1' > /usr/bin/trino \
  && chmod +x /usr/bin/trino-cli /usr/bin/trino \
  && trino-cli --version \
  \
  && pip3 install --break-system-packages minio==${MINIO_PY_VERSION} trino==${TRINO_PY_VERSION} \
  && python3 -c "import minio; print('minio {}'.format(minio.__version__))" \
  && python3 -c "import trino; print('trino {}'.format(trino.__version__))"
