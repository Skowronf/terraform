#!/usr/bin/env bash
set -euo pipefail

echo "=== Platform bootstrap ==="
./bootstrap/install-cilium.sh
./bootstrap/install-argocd.sh

echo "=== GitOps applications bootstrap ==="
./bootstrap/install-gitops-applications.sh
