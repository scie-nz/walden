#!/bin/bash

# script to run in devserver pod
read -d '' EXEC_SCRIPT << EOF
echo "mc alias"
mc alias set walden-minio/ http://minio:9000 \$MINIO_ACCESS_KEY_ID \$MINIO_ACCESS_KEY_SECRET || exit 1

echo "mc rb"
mc rb --force walden-minio/alluxio

echo "mc mb"
mc mb walden-minio/alluxio

trino_cmd() {
  echo "trino: \$1"
  trino-cli --server trino --user walden --execute="\$1"
}

trino_cmd "DROP TABLE IF EXISTS hive.alluxio.dim_bar"
trino_cmd "DROP SCHEMA IF EXISTS hive.alluxio"
trino_cmd "CREATE SCHEMA hive.alluxio WITH (location='alluxio://alluxio:19998/')"
trino_cmd "CREATE TABLE hive.alluxio.dim_bar(key VARCHAR, val BIGINT)"
trino_cmd "INSERT INTO hive.alluxio.dim_bar VALUES ('this', 4), ('is', 5), ('another', 6), ('test', 7)"
trino_cmd "SELECT key, val FROM hive.alluxio.dim_bar"

echo "mc ls"
mc ls -r walden-minio/alluxio
EOF

# Ensure alluxio is a clean slate. After dropping dim_bar, alluxio seems to leave the directory lying around...
kubectl exec -it -n walden alluxio-leader-0 -c leader -- /bin/bash -c "./bin/alluxio fs rm -R /dim_bar"

kubectl exec -it -n walden deployment/devserver -- /bin/bash -c "$EXEC_SCRIPT"
