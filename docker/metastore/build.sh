#!/bin/bash

# Allow custom tag via either METASTORE_TAG or TAG, default is current date
TAG=${METASTORE_TAG:=metastore-${TAG:=$(date +%Y.%m.%d)}}

# Allow custom registry/org via ORG
docker build . -t ${ORG:=ghcr.io/scie-nz}/walden:$TAG
