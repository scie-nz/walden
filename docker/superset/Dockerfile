# Based on the latest stable release: https://hub.docker.com/r/apache/superset/tags?page=1&name=.
FROM apache/superset:2.0.0

USER root

# Geckodriver prerequisites
ENV GECKODRIVER_VERSION=0.32.0
RUN apt-get update \
  && apt-get -y install --no-install-recommends firefox-esr \
  && apt-get -y upgrade \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists /var/cache/apt/archives \
  && wget https://github.com/mozilla/geckodriver/releases/download/v${GECKODRIVER_VERSION}/geckodriver-v${GECKODRIVER_VERSION}-linux64.tar.gz \
  && tar -x geckodriver -zf geckodriver-v${GECKODRIVER_VERSION}-linux64.tar.gz -O > /usr/bin/geckodriver \
  && rm geckodriver-v${GECKODRIVER_VERSION}-linux64.tar.gz \
  && chmod 755 /usr/bin/geckodriver \
  && geckodriver --version

USER superset

# Install a selection of drivers for connecting Superset to various database types and auth integrations.
# psycopg2-binary (postgres) and redis are required for internal communication and should not be removed.
#
# See here for full list of supported DBs and their connection strings:
#   https://superset.apache.org/docs/connecting-to-databases/installing-database-drivers
#
# The listed versions are the latest found in PyPI as of 2022/11
RUN pip install \
  authlib==1.1.0 \
  clickhouse-driver==0.2.4 \
  clickhouse-sqlalchemy==0.2.2 \
  cockroachdb==0.3.5 \
  elasticsearch-dbapi==0.2.9 \
  flask-oidc==1.4.0 \
  mysqlclient==2.1.1 \
  psycopg2-binary==2.9.5 \
  pyhive==0.6.5 \
  redis==4.3.4 \
  sqlalchemy-trino==0.5.0
