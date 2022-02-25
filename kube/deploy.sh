#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [ -z "$1" ]; then
    echo "Syntax: $0 <values.yaml>"
    echo "If you just wish to use the defaults, then run: $0 values-default.yaml"
    exit 1
fi
VALUES_FILE="$1"
if [ ! -f "$VALUES_FILE" ]; then
    echo "File not found (or not a file): $VALUES_FILE"
    exit 1
fi

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

# force upgrade to work, otherwise get 'Error: UPGRADE FAILED: "walden" has no deployed releases'
# might be fixed with https://github.com/helm/helm/pull/7653/
kubectl delete secret sh.helm.release.v1.${RELEASE_NAME}.v1 --ignore-not-found

# NOTE: Ideally we'd do 'helm template | kubectl apply' but this breaks lookup of randomly generated secrets.
echo "Using values file: $VALUES_FILE"
helm upgrade --install --debug --values $VALUES_FILE $RELEASE_NAME $SCRIPT_DIR
