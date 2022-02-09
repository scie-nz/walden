# Based on the latest stable release
# TODO: After this has been upgraded to 1.5.x, update psycopg2-binary below to whatever's latest
FROM apache/superset:1.4.0

# Install a selection of drivers for connecting Superset to various common database types.
# psycopg2-binary (postgres) and redis are required for internal communication and should not be removed.
#
# See here for full list of supported DBs and their connection strings:
#   https://superset.apache.org/docs/connecting-to-databases/installing-database-drivers
#
# The listed versions are the latest found in PyPI as 2022/02, EXCEPT FOR psycopg2-binary,
# where using latest (2.9.3 as of writing) creates problems with DATETIME columns:
#   https://github.com/apache/superset/issues/15768
# This is fixed in a recent Superset commit to master, but it hasn't been released yet (1.5.x?):
#   https://github.com/apache/superset/pull/17713
RUN pip install \
  clickhouse-driver==0.2.3 \
  clickhouse-sqlalchemy==0.1.8 \
  cockroachdb==0.3.5 \
  elasticsearch-dbapi==0.2.7 \
  mysqlclient==2.1.0 \
  psycopg2-binary==2.8.6 \
  pyhive==0.6.4 \
  redis==4.1.2 \
  sqlalchemy-trino==0.4.1
