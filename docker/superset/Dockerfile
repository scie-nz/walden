# Based on the latest stable release
# TODO: After this has been upgraded to 1.5.x, update stuck dependencies below to whatever's latest
FROM apache/superset:1.4.2

# Install a selection of drivers for connecting Superset to various common database types.
# psycopg2-binary (postgres) and redis are required for internal communication and should not be removed.
#
# See here for full list of supported DBs and their connection strings:
#   https://superset.apache.org/docs/connecting-to-databases/installing-database-drivers
#
# The listed versions are the latest found in PyPI as 2022/03, EXCEPT FOR:
# - psycopg2-binary, where using latest (2.9.3 as of writing) creates problems with DATETIME columns:
#     https://github.com/apache/superset/issues/15768
#   This is fixed in a recent Superset commit to master, but it hasn't been released yet (1.5.x?):
#     https://github.com/apache/superset/pull/17713
# - clickhouse-sqlalchemy, where using latest (0.2.0 as of writing) instantly crashes sqlalchemy workers
#   due to missing sqlalchemy.engine.RowProxy in sqlalchemy 1.4+ (which is what 0.2.0+ is now using)
# - redis, where using latest (4.2.0 as of writing) instantly crashes superset due to version mismatch
#   on async-timeout (redis 4.2.0 wants async-timeout 4.x, when superset 1.4.x wants something else)
RUN pip install \
  clickhouse-driver==0.2.3 \
  clickhouse-sqlalchemy==0.1.8 \
  cockroachdb==0.3.5 \
  elasticsearch-dbapi==0.2.9 \
  mysqlclient==2.1.0 \
  psycopg2-binary==2.8.6 \
  pyhive==0.6.5 \
  redis==4.1.4 \
  sqlalchemy-trino==0.4.1
