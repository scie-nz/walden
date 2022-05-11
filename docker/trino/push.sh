#!/bin/bash

# Allow custom tag via either TRINO_TAG or TAG, default is current date
TAG=${TRINO_TAG:=${TAG:=$(date +%Y.%m.%d)}}

# Allow custom registry/org via ORG
docker push ${ORG:=docker.io/scienz}/walden-trino:${TAG}
