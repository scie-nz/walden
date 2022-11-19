#!/bin/bash

# script to run in devserver pod
read -d '' EXEC_SCRIPT << EOF
echo "mc alias"
mc alias set walden-minio/ http://minio:9000 \$MINIO_ACCESS_KEY_ID \$MINIO_ACCESS_KEY_SECRET || exit 1

echo "mc rb"
mc rb --force walden-minio/direct

echo "mc mb"
mc mb walden-minio/direct

trino_cmd() {
  echo "trino: \$1"
  trino-cli --server trino --user walden --execute="\$1"
}

trino_cmd "DROP TABLE IF EXISTS hive.direct.dim_foo"
trino_cmd "DROP SCHEMA IF EXISTS hive.direct"
trino_cmd "CREATE SCHEMA hive.direct WITH (location='s3a://direct/')"
trino_cmd "CREATE TABLE hive.direct.dim_foo(key VARCHAR, val BIGINT)"
trino_cmd "INSERT INTO hive.direct.dim_foo VALUES ('this', 1), ('is', 2), ('a', 3), ('test', 4)"
trino_cmd "SELECT key, val FROM hive.direct.dim_foo"

echo "mc ls"
mc ls -r walden-minio/direct
EOF

kubectl exec -it -n walden deployment/devserver -- /bin/bash -c "$EXEC_SCRIPT"
