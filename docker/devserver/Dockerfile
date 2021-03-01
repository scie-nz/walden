FROM ubuntu:20.10
RUN apt-get update && apt-get -y install gnupg2 curl wget openjdk-11-jre less python3-pip vim git unzip
RUN apt-get -y upgrade

WORKDIR /usr/bin

RUN wget https://repo1.maven.org/maven2/io/trino/trino-cli/352/trino-cli-352-executable.jar
RUN chmod a+rwx trino-cli-352-executable.jar
RUN ln -s trino-cli-352-executable.jar trino-cli
RUN echo 'trino-cli --server trino-coordinator-headless:8080 --catalog hive --schema $1' > /usr/bin/trino
RUN chmod a+rwx /usr/bin/trino

RUN pip3 install presto-python-client minio
RUN wget https://dl.min.io/client/mc/release/linux-amd64/mc
RUN chmod +x mc
RUN DEBIAN_FRONTEND="noninteractive" apt-get -y install tzdata

WORKDIR /home/root
COPY entrypoint.sh .
ENTRYPOINT ["/home/root/entrypoint.sh"]
