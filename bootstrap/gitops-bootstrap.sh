#!/usr/bin/env bash

set -euo pipefail

readonly GITOPS_REPO="https://github.com/Skowronf/kubernetes"
readonly GITOPS_REVISION="main"
readonly GITOPS_PATH="gitops/aws"

echo "Installing AWS GitOps Applications"

kubectl apply -f \
  "${GITOPS_REPO}/raw/${GITOPS_REVISION}/${GITOPS_PATH}/"
