#!/bin/bash

# Allow custom tag via either WALDEN_DEVSERVER_TAG or WALDEN_TAG, default is current date
TAG=${WALDEN_DEVSERVER_TAG:=${WALDEN_TAG:=$(date +%Y.%m.%d)}}

# Allow custom registry/org via WALDEN_ORG
docker push ${WALDEN_ORG:=docker.io/scienz}/walden-devserver:$TAG
