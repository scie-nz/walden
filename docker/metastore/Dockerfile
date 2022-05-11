# Loosely based on: https://techjogging.com/standalone-hive-metastore-presto-docker.html

# Use current LTS
FROM ubuntu:22.04

ENV HADOOP_VERSION=3.3.1 \
  METASTORE_VERSION=3.1.2 \
  ALLUXIO_VERSION=2.7.3 \
  POSTGRES_JDBC_VERSION=42.3.2 \
  AWS_SDK_JAR_VERSION=1.11.901 \
  HADOOP_HOME=/opt/hadoop \
  HIVE_HOME=/opt/hive-metastore \
  DEBIAN_FRONTEND="noninteractive"

RUN mkdir -p $HIVE_HOME/lib \
  && mkdir -p $HADOOP_HOME \
  && chmod a+rw $HIVE_HOME \
  && chmod a+rw $HIVE_HOME/lib \
  && chmod a+rw $HADOOP_HOME \
  \
  && apt-get update \
  && apt-get -y install gnupg2 curl openjdk-8-jre \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists /var/cache/apt/archives \
  \
  && curl -L https://repo1.maven.org/maven2/org/apache/hive/hive-standalone-metastore/${METASTORE_VERSION}/hive-standalone-metastore-${METASTORE_VERSION}-bin.tar.gz | tar zxf - \
  && mv apache-hive-metastore-${METASTORE_VERSION}-bin/* $HIVE_HOME \
  && rmdir -v apache-hive-metastore-${METASTORE_VERSION}-bin \
  \
  && curl -L https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz | tar zxf - \
  && mv -v hadoop-${HADOOP_VERSION}/* $HADOOP_HOME \
  && rmdir -v hadoop-${HADOOP_VERSION} \
  \
  && curl -O https://repo1.maven.org/maven2/org/alluxio/alluxio-shaded-client/${ALLUXIO_VERSION}/alluxio-shaded-client-${ALLUXIO_VERSION}.jar \
  && mv -v alluxio-shaded-client-${ALLUXIO_VERSION}.jar $HIVE_HOME/lib/ \
  \
  && curl -O https://jdbc.postgresql.org/download/postgresql-${POSTGRES_JDBC_VERSION}.jar \
  && mv -v postgresql-${POSTGRES_JDBC_VERSION}.jar $HIVE_HOME/lib/ \
  \
  && stat $HADOOP_HOME/share/hadoop/tools/lib/aws-java-sdk-bundle-$AWS_SDK_JAR_VERSION.jar \
  && cp -v $HADOOP_HOME/share/hadoop/tools/lib/aws-java-sdk-bundle-$AWS_SDK_JAR_VERSION.jar $HIVE_HOME/lib/ \
  && cp -v $HADOOP_HOME/share/hadoop/tools/lib/hadoop-aws-$HADOOP_VERSION.jar $HIVE_HOME/lib/ \
  \
  && rm -v $HIVE_HOME/lib/guava-*.jar \
  && stat $HADOOP_HOME/share/hadoop/common/lib/guava-27.0-jre.jar \
  && cp -v $HADOOP_HOME/share/hadoop/common/lib/guava-27.0-jre.jar $HIVE_HOME/lib/

ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 \
  HADOOP_CLASSPATH=$HADOOP_CLASSPATH:$HIVE_HOME/lib/aws-java-sdk-bundle-$AWS_SDK_JAR_VERSION.jar:$HIVE_HOME/lib/hadoop-aws-$HADOOP_VERSION.jar:$HIVE_HOME/lib/postgresql-$POSTGRES_JDBC_VERSION.jar \
  METASTORE_AUX_JARS_PATH=$HIVE_HOME/lib/aws-java-sdk-bundle-$AWS_SDK_JAR_VERSION.jar:$HIVE_HOME/lib/hadoop-aws-$HADOOP_VERSION.jar:$HIVE_HOME/lib/alluxio-shaded-client-$ALLUXIO_VERSION.jar
