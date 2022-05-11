#!/bin/bash

# Allow custom tag via either METASTORE_TAG or TAG, default is current date
TAG=${METASTORE_TAG:=${TAG:=$(date +%Y.%m.%d)}}

# Allow custom registry/org via ORG
docker build . -t ${ORG:=docker.io/scienz}/walden-metastore:$TAG
