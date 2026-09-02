set -euo pipefail

readonly ARGOCD_NAMESPACE="argocd"
readonly ARGOCD_VERSION="v3.4.6"
readonly ARGOCD_MANIFEST_URL="https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
readonly ARGOCD_TIMEOUT="280s"

echo "Creating Argo CD namespace"

kubectl create namespace "$ARGOCD_NAMESPACE" \
  --dry-run=client \
  -o yaml | kubectl apply -f -

echo "Installing Argo CD ${ARGOCD_VERSION}"

kubectl apply \
  --server-side \
  -n "$ARGOCD_NAMESPACE" \
  -f "$ARGOCD_MANIFEST_URL"

echo "Waiting for Argo CD"

kubectl wait \
  --for=condition=available \
  deployment/argocd-server \
  -n "$ARGOCD_NAMESPACE" \
  --timeout="$ARGOCD_TIMEOUT"

echo "Argo CD installation completed"

kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo
