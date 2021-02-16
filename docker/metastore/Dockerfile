# Loosely based on: https://techjogging.com/standalone-hive-metastore-presto-docker.html

FROM ubuntu:20.10

ENV HADOOP_VERSION=3.2.2
ENV METASTORE_VERSION=3.1.2

ENV HADOOP_HOME=/opt/hadoop-${HADOOP_VERSION}
ENV HIVE_HOME=/opt/apache-hive-metastore-${METASTORE_VERSION}-bin
ENV DEBIAN_FRONTEND="noninteractive"

RUN mkdir -p $HIVE_HOME && chmod a+rw $HIVE_HOME && mkdir -p $HIVE_HOME/lib \
  && chmod a+rw $HIVE_HOME/lib && mkdir -p $HADOOP_HOME && chmod a+rw $HADOOP_HOME


RUN apt-get update && apt-get -y install gnupg2 curl openjdk-8-jre

RUN curl -L https://repo1.maven.org/maven2/org/apache/hive/hive-standalone-metastore/${METASTORE_VERSION}/hive-standalone-metastore-${METASTORE_VERSION}-bin.tar.gz | tar zxf -
RUN curl -L https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz | tar zxf -
RUN curl -O https://jdbc.postgresql.org/download/postgresql-42.2.16.jar

RUN mv postgresql-42.2.16.jar ${HIVE_HOME}/lib/
RUN mv hadoop-${HADOOP_VERSION}/* $HADOOP_HOME

RUN ln -s $HADOOP_HOME/share/hadoop/tools/lib/aws-java-sdk-bundle-1.11.563.jar $HIVE_HOME/lib/.
RUN ln -s $HADOOP_HOME/share/hadoop/tools/lib/hadoop-aws-$HADOOP_VERSION.jar $HIVE_HOME/lib/.

ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
ENV HADOOP_CLASSPATH=$HADOOP_CLASSPATH:$HIVE_HOME/lib/aws-java-sdk-bundle-1.11.563.jar
ENV HADOOP_CLASSPATH=$HADOOP_CLASSPATH:$HIVE_HOME/lib/hadoop-aws-$HADOOP_VERSION.jar
ENV HADOOP_CLASSPATH=$HADOOP_CLASSPATH:$HIVE_HOME/lib/postgresql-42.2.16.jar

ENV METASTORE_AUX_JARS_PATH=/alluxio-2.4.0/client/alluxio-2.4.0-client.jar:$HIVE_HOME/lib/aws-java-sdk-bundle-1.11.563.jar:$HIVE_HOME/lib/hadoop-aws-$HADOOP_VERSION.jar

WORKDIR apache-hive-metastore-${METASTORE_VERSION}-bin
RUN rm lib/guava-19.0.jar
RUN cp $HADOOP_HOME/share/hadoop/common/lib/guava-27.0-jre.jar lib/

COPY entrypoint.sh /
EXPOSE 9083
ENTRYPOINT ["/entrypoint.sh"]
