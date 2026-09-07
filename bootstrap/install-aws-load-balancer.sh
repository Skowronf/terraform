#!/usr/bin/env bash

set -euo pipefail

readonly GITOPS_REPO="https://github.com/Skowronf/kubernetes"
readonly GITOPS_REVISION="main"
readonly GITOPS_PATH="gitops/aws/aws-load-balancer.yml"

echo "Installing AWS aws-load-balancer Argo CD Application"

kubectl apply -f \
  "${GITOPS_REPO}/raw/${GITOPS_REVISION}/${GITOPS_PATH}"
