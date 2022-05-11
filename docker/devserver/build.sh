#!/bin/bash

# Allow custom tag via either DEVSERVER_TAG or TAG, default is current date
TAG=${DEVSERVER_TAG:=${TAG:=$(date +%Y.%m.%d)}}

# Allow custom registry/org via ORG
docker build . -t ${ORG:=docker.io/scienz}/walden-devserver:$TAG
