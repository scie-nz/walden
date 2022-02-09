# Based on the latest stable release
FROM apache/superset:1.4.0

# Install a selection of drivers for connecting Superset to various common database types.
# psycopg2-binary (postgres) and redis are required for internal communication and should not be removed.
#
# See here for full list of supported DBs and their connection strings:
#   https://superset.apache.org/docs/connecting-to-databases/installing-database-drivers
#
# The listed versions are the latest found in PyPI as of the last check.
RUN pip install \
  clickhouse-driver==0.2.3 \
  clickhouse-sqlalchemy==0.1.8 \
  cockroachdb==0.3.5 \
  elasticsearch-dbapi==0.2.7 \
  mysqlclient==2.1.0 \
  psycopg2-binary==2.9.3 \
  pyhive==0.6.4 \
  redis==4.1.2 \
  sqlalchemy-trino==0.4.1
