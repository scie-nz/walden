#!/bin/bash

# Allow custom tag via either DEVSERVER_TAG or TAG, default is current date
TAG=${DEVSERVER_TAG:=devserver-${TAG:=$(date +%Y.%m.%d)}}

# Allow custom registry/org via ORG
docker build . -t ${ORG:=ghcr.io/scie-nz}/walden:$TAG
