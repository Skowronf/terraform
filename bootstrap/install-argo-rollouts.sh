#!/usr/bin/env bash

set -euo pipefail

readonly GITOPS_REPO="https://github.com/Skowronf/kubernetes"
readonly GITOPS_REVISION="main"
# argo rollous seems to be the same for local and aws, pro might be deleted 
# from k8s repo to not keep duplicated code
readonly GITOPS_PATH="gitops/aws/argo-rollouts.yml"

echo "Installing Argo Rollouts Argo CD Application"

kubectl apply -f \
  "${GITOPS_REPO}/raw/${GITOPS_REVISION}/${GITOPS_PATH}"
