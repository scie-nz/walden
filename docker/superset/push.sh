#!/bin/bash

# Allow custom tag via either SUPERSET_TAG or TAG, default is current date
TAG=${SUPERSET_TAG:=superset-${TAG:=$(date +%Y.%m.%d)}}

# Allow custom registry/org via ORG
docker push ${ORG:=ghcr.io/scie-nz}/walden:$TAG
