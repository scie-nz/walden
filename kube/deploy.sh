#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# strict mode
set -euo pipefail
IFS=$'\n\t'

# print line on error
err_report() {
    echo "Error on line $1"
}
trap 'err_report $LINENO' ERR

# set namespace, then reset back to current afterwards
# this allows us to apply across namespaces in a single 'apply' command, while still having an assigned default
TARGET_NAMESPACE=walden
ORIG_NAMESPACE=$(kubectl config view --minify --output 'jsonpath={..namespace}')
if [ -z "$ORIG_NAMESPACE" ]; then
    ORIG_NAMESPACE=$TARGET_NAMESPACE
fi
reset_namespace() {
    echo "Switching back to namespace: $ORIG_NAMESPACE"
    kubectl config set-context --current --namespace=$ORIG_NAMESPACE
}
trap reset_namespace EXIT

echo "Switching to namespace: $TARGET_NAMESPACE"
# if namespace doesn't exist, create it
kubectl create namespace $TARGET_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
kubectl config set-context --current --namespace=$TARGET_NAMESPACE

RELEASE_NAME=walden
# Update this default after pushing new release images:
WALDEN_VERSION=2022.02.08

# force upgrade to work, otherwise get 'Error: UPGRADE FAILED: "walden" has no deployed releases'
# might be fixed with https://github.com/helm/helm/pull/7653/
kubectl delete secret sh.helm.release.v1.${RELEASE_NAME}.v1 --ignore-not-found

# Deployment options:
# - WALDEN_ORG: Allow overriding the registry/organization for pulling all walden images.
# - WALDEN_TAG/WALDEN_*_TAG: Configure tags for all walden images, or for individual images.
# - MINIO_ARCH: In mixed-arch clusters, allow running minio on ARM nodes.
# NOTE: Ideally we'd do 'helm template | kubectl apply' but this breaks lookup of randomly generated secrets.
helm upgrade \
  --install \
  --debug \
  --set walden_docker_org=${WALDEN_ORG:=docker.io/scienz} \
  --set walden_devserver_tag=${WALDEN_DEVSERVER_TAG:=${WALDEN_TAG:=$WALDEN_VERSION}} \
  --set walden_metastore_tag=${WALDEN_METASTORE_TAG:=${WALDEN_TAG:=$WALDEN_VERSION}} \
  --set walden_trino_tag=${WALDEN_TRINO_TAG:=${WALDEN_TAG:=$WALDEN_VERSION}} \
  --set minio_arch=${MINIO_ARCH:=amd64} \
  ${RELEASE_NAME} $SCRIPT_DIR
