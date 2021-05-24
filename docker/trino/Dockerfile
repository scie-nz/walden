FROM azul/zulu-openjdk:11

RUN apt-get update && apt-get -y install gnupg2 curl
RUN echo "presto soft nofile 131072" >> /etc/security/limits.conf
RUN echo "presto hard nofile 131072" >> /etc/security/limits.conf

RUN apt-get -y install keychain
RUN mkdir -p /root/.ssh \
  && ssh-keygen -t rsa -N '' -f /root/.ssh/id_rsa \
  && chmod 600 /root/.ssh/id* \
  && cp /root/.ssh/id_rsa /etc/ssh/ssh_host_key \
  && cat /root/.ssh/id_rsa.pub >>/root/.ssh/authorized_keys \
  && echo "session required pam_limits.so" >> /etc/pam.d/common-session

ENV DEBIAN_FRONTEND="noninteractive"

ENV MVN_MIRROR="https://repo1.maven.org/maven2/"
RUN curl -O https://repo1.maven.org/maven2/io/trino/trino-server/356/trino-server-356.tar.gz \
  && tar -xvf trino-server-356.tar.gz

WORKDIR trino-server-356
RUN mkdir -p etc
RUN mkdir -p etc/catalog

RUN ln -s /usr/bin/python3 /usr/bin/python
RUN apt-get install -y uuid-runtime
COPY entrypoint.sh /

RUN apt-get update --fix-missing
RUN apt-get install -y software-properties-common
RUN add-apt-repository ppa:deadsnakes/ppa
RUN apt-get update
RUN apt-get install -y python3.8

RUN apt-get install -y git
RUN git clone https://github.com/scie-nz/TileDB-Trino.git
RUN cd TileDB-Trino && git checkout 356 && ./mvnw package -DskipTests=true
RUN mv TileDB-Trino/target/trino-tiledb-356.jar plugin/hive-hadoop2/

ENTRYPOINT ["/entrypoint.sh"]
