#!/bin/bash

# Allow custom tag via either WALDEN_METASTORE_TAG or WALDEN_TAG, default is current date
TAG=${WALDEN_METASTORE_TAG:=${WALDEN_TAG:=$(date +%Y.%m.%d)}}

# Allow custom registry/org via WALDEN_ORG
docker build . -t ${WALDEN_ORG:=docker.io/scienz}/walden-metastore:$TAG
