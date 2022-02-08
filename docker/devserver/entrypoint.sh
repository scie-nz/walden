#!/bin/bash
cd ~
mc alias set walden-minio/ http://minio:9000 $MINIO_ACCESS_KEY_ID $MINIO_ACCESS_KEY_SECRET
while true; do sleep 30; done;
