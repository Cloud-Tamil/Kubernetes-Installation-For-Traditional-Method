#!/usr/bin/env bash
set -euo pipefail

echo "=== Deleting namespace shopsphere ==="
kubectl delete namespace shopsphere --ignore-not-found

echo "=== Removing local Docker images ==="
docker rmi shopsphere/backend:1.0.0 2>/dev/null || true
docker rmi shopsphere/frontend:1.0.0 2>/dev/null || true

echo "=== Done ==="
