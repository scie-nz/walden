# Based on the latest stable release
FROM apache/superset:1.5.0

USER root
# Geckodriver prerequisites
RUN apt-get update \
  && apt-get -y install --no-install-recommends firefox-esr \
  && apt-get -y upgrade \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists /var/cache/apt/archives
USER superset

# Install a selection of drivers for connecting Superset to various database types and auth integrations.
# psycopg2-binary (postgres) and redis are required for internal communication and should not be removed.
#
# See here for full list of supported DBs and their connection strings:
#   https://superset.apache.org/docs/connecting-to-databases/installing-database-drivers
#
# The listed versions are the latest found in PyPI as of 2022/05, EXCEPT FOR:
# - clickhouse-sqlalchemy, where using latest (0.2.0 as of writing) instantly crashes sqlalchemy workers
#   due to missing sqlalchemy.engine.RowProxy in sqlalchemy 1.4+ (which is what 0.2.0+ is now using)
# - redis, where using 4.2.0+ instantly crashes superset due to version mismatch
#   on async-timeout (redis 4.2.0+ wants async-timeout 4.x, when superset 1.4.x wants 3.x)
RUN pip install \
  authlib==1.0.1 \
  clickhouse-driver==0.2.3 \
  clickhouse-sqlalchemy==0.1.8 \
  cockroachdb==0.3.5 \
  elasticsearch-dbapi==0.2.9 \
  flask-oidc==1.4.0 \
  mysqlclient==2.1.0 \
  psycopg2-binary==2.9.3 \
  pyhive==0.6.5 \
  redis==4.1.4 \
  sqlalchemy-trino==0.4.1

ENV GECKODRIVER_VERSION=0.31.0
USER root
RUN wget https://github.com/mozilla/geckodriver/releases/download/v${GECKODRIVER_VERSION}/geckodriver-v${GECKODRIVER_VERSION}-linux64.tar.gz \
  && tar -x geckodriver -zf geckodriver-v${GECKODRIVER_VERSION}-linux64.tar.gz -O > /usr/bin/geckodriver \
  && rm geckodriver-v${GECKODRIVER_VERSION}-linux64.tar.gz \
  && chmod 755 /usr/bin/geckodriver \
  && geckodriver --version
USER superset
