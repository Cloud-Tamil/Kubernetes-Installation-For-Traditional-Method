#!/usr/bin/env bash
set -euo pipefail

NS=shopsphere

echo "=== Nodes ==="
kubectl get nodes -o wide

echo "=== Namespace resources ==="
kubectl get all -n $NS

echo "=== PVCs ==="
kubectl get pvc -n $NS

echo "=== Ingress ==="
kubectl get ingress -n $NS

echo "=== HPA ==="
kub
