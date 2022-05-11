#!/bin/bash

# Allow custom tag via either SUPERSET_TAG or TAG, default is current date
TAG=${SUPERSET_TAG:=${TAG:=$(date +%Y.%m.%d)}}

# Allow custom registry/org via ORG
docker build . -t ${ORG:=docker.io/scienz}/walden-superset:$TAG
