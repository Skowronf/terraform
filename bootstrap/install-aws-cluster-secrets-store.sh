#!/usr/bin/env bash

set -euo pipefail

readonly GITOPS_REPO="https://github.com/Skowronf/kubernetes"
readonly GITOPS_REVISION="main"
readonly GITOPS_PATH="aws-platform/cluster-secret-store.yml"

echo "Installing AWS cluster-secret-store Argo CD Application"

kubectl apply -f \
  "${GITOPS_REPO}/raw/${GITOPS_REVISION}/${GITOPS_PATH}"
