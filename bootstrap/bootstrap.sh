#!/usr/bin/env bash
set -euo pipefail

echo "=== Platform bootstrap ==="

./bootstrap/install-cilium.sh
./bootstrap/install-argocd.sh

echo "=== AWS platform components ==="
# Once stabilized remove below and use gitops-bootstrap.sh instead
./bootstrap/install-aws-load-balancer.sh
./bootstrap/install-aws-secrets-store.sh
./bootstrap/install-aws-secrets-manager.sh
# Need a minute here
sleep 3m
./bootstrap/install-aws-cluster-secrets-store.sh
./bootstrap/install-argo-rollouts.sh


echo "=== Applications ==="

./bootstrap/install-petclinic.sh
