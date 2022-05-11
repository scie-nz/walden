# Use whatever is the latest JRE 11.0.x version
# -> https://hub.docker.com/r/azul/zulu-openjdk/tags?page=1&name=11
# Trino requires JRE 11, minimum 11.0.11 - newer versions are not tested
FROM azul/zulu-openjdk:11.0.15

ENV DEBIAN_FRONTEND="noninteractive" \
  MVN_MIRROR="https://repo1.maven.org/maven2/"

RUN apt-get update --fix-missing \
  && apt-get -y install apache2-utils curl gnupg2 keychain python3.8 software-properties-common uuid-runtime gettext-base \
  && add-apt-repository ppa:deadsnakes/ppa \
  && apt-get update --fix-missing \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists /var/cache/apt/archives \
  \
  && ln -s /usr/bin/python3 /usr/bin/python \
  \
  && echo "presto soft nofile 131072" >> /etc/security/limits.conf \
  && echo "presto hard nofile 131072" >> /etc/security/limits.conf \
  && echo "session required pam_limits.so" >> /etc/pam.d/common-session \
  \
  && groupadd -g 1000 trino \
  && useradd -d /trino-server -s /bin/bash -u 1000 -g 1000 trino

# Install Trino to /trino-server as a separate stage at the end.
# Maximizes caching when switching versions.
# Note that Trino already includes alluxio-shaded-client-<version>.jar
ENV TRINO_VERSION=380

RUN curl https://repo1.maven.org/maven2/io/trino/trino-server/${TRINO_VERSION}/trino-server-${TRINO_VERSION}.tar.gz | tar xzf - \
  && mv -v trino-server-${TRINO_VERSION}/ trino-server/ \
  && mkdir -p trino-server/etc/catalog \
  && chown -R trino:trino trino-server

WORKDIR /trino-server
USER trino
