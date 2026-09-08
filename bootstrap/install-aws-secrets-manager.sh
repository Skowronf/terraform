#!/usr/bin/env bash

set -euo pipefail

readonly GITOPS_REPO="https://github.com/Skowronf/kubernetes"
readonly GITOPS_REVISION="main"
readonly GITOPS_PATH="gitops/aws/external-secrets.yml"

echo "Installing AWS external-secrets Argo CD Application"

kubectl apply -f \
  "${GITOPS_REPO}/raw/${GITOPS_REVISION}/${GITOPS_PATH}"
