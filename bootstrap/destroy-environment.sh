#!/usr/bin/env bash
set -euo pipefail

REGION="eu-central-1"

echo "==> Stopping Argo CD reconciliation for all Applications"

kubectl -n argocd annotate applications.argoproj.io \
  --all \
  argocd.argoproj.io/skip-reconcile=true \
  --overwrite

echo "==> Argo CD reconciliation disabled"

echo "==> Currently paused Applications:"
kubectl -n argocd get applications \
  -o custom-columns=NAME:.metadata.name,SKIP_RECONCILE:.metadata.annotations.argocd\\.argoproj\\.io/skip-reconcile

# -------------------------------------------------------------------
# Delete Kubernetes resources which own AWS resources.
#
# IMPORTANT:
# AWS Load Balancer Controller is still running.
#
# Therefore deleting the Ingress allows the controller to notice
# the deletion and remove the AWS ALB.
# -------------------------------------------------------------------

echo "==> Removing Kubernetes-managed AWS resources"

kubectl delete ingress petclinic-alb \
  -n petclinic \
  --ignore-not-found

echo "==> Waiting for AWS Load Balancer Controller cleanup"

for i in {1..30}; do

    ALB_COUNT=$(aws elbv2 describe-load-balancers \
        --region "$REGION" \
        --query 'length(LoadBalancers[])' \
        --output text)

    if [[ "$ALB_COUNT" == "0" ]]; then
        echo "    All ALBs removed."
        break
    fi

    echo "    Waiting for ALB cleanup... ($i/30)"
    sleep 10
done

ALB_COUNT=$(aws elbv2 describe-load-balancers \
    --region "$REGION" \
    --query 'length(LoadBalancers[])' \
    --output text)

if [[ "$ALB_COUNT" != "0" ]]; then
    echo "ERROR: ALB still exists."
    echo "Check:"
    echo "  aws elbv2 describe-load-balancers --region $REGION"
    exit 1
fi

echo "==> Kubernetes-owned AWS resources cleaned up"

echo "==> Ready for terraform destroy"
