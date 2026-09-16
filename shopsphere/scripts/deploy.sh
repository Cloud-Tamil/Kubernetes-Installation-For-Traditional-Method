#!/usr/bin/env bash
set -euo pipefail

NS=shopsphere

echo "=== Namespace ==="
kubectl apply -f k8s/namespace/

echo "=== Config ==="
kubectl apply -f k8s/config/

echo "=== Policies (quota + limits) ==="
kubectl apply -f k8s/policies/

echo "=== RBAC ==="
kubectl apply -f k8s/rbac/

echo "=== Database ==="
kubectl apply -f k8s/database/

echo "=== Redis ==="
kubectl apply -f k8s/redis/

echo "=== Backend ==="
kubectl apply -f k8s/backend/

echo "=== Frontend ==="
kubectl apply -f k8s/frontend/

echo "=== Network policies ==="
kubectl apply -f k8s/network/

echo "=== Ingress ==="
kubectl apply -f k8s/ingress/

echo "=== Waiting for rollouts ==="
kubectl rollout status statefulset/postgres -n $NS --timeout=180s
kubectl rollout status deployment/redis -n $NS --timeout=120s
kubectl rollout status deployment/shopsphere-backend -n $NS --timeout=180s
kubectl rollout status deployment/shopsphere-frontend -n $NS --timeout=180s

echo "=== Done ==="
