#!/usr/bin/env bash
set -euo pipefail

TAG="${1:-1.0.0}"

echo "=== Building backend:${TAG} ==="
docker build -t shopsphere/backend:${TAG} -f docker/backend/Dockerfile .

echo "=== Building frontend:${TAG} ==="
docker build -t shopsphere/frontend:${TAG} -f docker/frontend/Dockerfile .

echo "=== Done ==="
docker images | grep shopsphere
