#!/usr/bin/env bash
set -euo pipefail

echo "=== Platform bootstrap ==="
./bootstrap/install-cilium.sh
./bootstrap/install-argocd.sh
./bootstrap/install-gitops-applications.sh
