#!/usr/bin/env bash
set -euo pipefail

echo "Installing Cilium with AWS VPC CNI chaining"

cilium install \
  --version 1.20.1 \
  --set cni.chainingMode=aws-cni \
  --set cni.exclusive=false \
  --set routingMode=native \
  --set enableIPv4Masquerade=false \
  --set kubeProxyReplacement=false

echo "Waiting for Cilium to be ready"

cilium status --wait
