#!/usr/bin/env bash
set -euo pipefail

echo "=== Platform bootstrap ==="
./bootstrap/install-cilium.sh
./bootstrap/install-argocd.sh

echo "=== GitOps applications bootstrap ==="
./bootstrap/install-ingress-nginx.sh
./bootstrap/install-aws-load-balancer.sh
