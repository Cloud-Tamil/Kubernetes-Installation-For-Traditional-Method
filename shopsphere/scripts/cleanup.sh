#!/usr/bin/env bash
set -euo pipefail

echo ">>> Deleting namespace shopsphere (all resources inside go with it)"
kubectl delete namespace shopsphere --ignore-not-found

echo ">>> Removing local images"
docker rmi shopsphere/backend:1.0.0  2>/dev/null || true
docker rmi shopsphere/frontend:1.0.0 2>/dev/null || true

echo ">>> Done"
