#!/usr/bin/env bash
set -euo pipefail

NS=shopsphere

echo ">>> Namespace"
kubectl apply -f k8s/namespace/

echo ">>> Config"
kubectl apply -f k8s/config/

echo ">>> Policies"
kubectl apply -f k8s/policies/

echo ">>> RBAC"
kubectl apply -f k8s/rbac/

echo ">>> Storage (skip if you already have a default StorageClass)"
kubectl get storageclass 2>/dev/null | grep -q '(default)' || \
  echo "    (no default StorageClass — PVCs will be Pending)"

echo ">>> PostgreSQL"
kubectl apply -f k8s/database/postgres.yaml

echo "    Waiting for postgres to be ready..."
kubectl rollout status statefulset/postgres -n "$NS" --timeout=240s

echo ">>> PostgreSQL schema init"
kubectl delete job postgres-init -n "$NS" --ignore-not-found
kubectl apply -f k8s/database/postgres-init.yaml

echo ">>> Redis"
kubectl apply -f k8s/redis/redis.yaml
kubectl rollout status statefulset/redis -n "$NS" --timeout=120s

echo ">>> Backend"
kubectl apply -f k8s/backend/

echo ">>> Frontend"
kubectl apply -f k8s/frontend/

echo ">>> NetworkPolicy"
CNI=$(kubectl get pods -n kube-system -o name 2>/dev/null | grep -E 'calico|cilium|weave|antrea' || true)
if [ -n "$CNI" ]; then
  kubectl apply -f k8s/network/
else
  echo "    ⚠  Skipped — no NetworkPolicy-capable CNI installed"
fi

echo ">>> Ingress"
kubectl apply -f k8s/ingress/

echo ""
echo ">>> Waiting for rollouts"
kubectl rollout status deployment/shopsphere-backend  -n "$NS" --timeout=300s
kubectl rollout status deployment/shopsphere-frontend -n "$NS" --timeout=300s

echo ""
echo "======================================"
echo "  Deployment complete."
echo "======================================"
