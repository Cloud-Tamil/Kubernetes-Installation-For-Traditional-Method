#!/usr/bin/env bash
set -euo pipefail

TAG="${1:-1.0.0}"

echo ">>> Building backend:${TAG}"
docker build -t "shopsphere/backend:${TAG}" -f docker/backend/Dockerfile .

echo ">>> Building frontend:${TAG}"
docker build -t "shopsphere/frontend:${TAG}" -f docker/frontend/Dockerfile .

echo ""
echo ">>> Images:"
docker images | grep shopsphere

echo ""
echo "If you are using minikube, load images into it:"
echo "  minikube image load shopsphere/backend:${TAG}"
echo "  minikube image load shopsphere/frontend:${TAG}"
echo ""
echo "If you are using kind, load images:"
echo "  kind load docker-image shopsphere/backend:${TAG}"
echo "  kind load docker-image shopsphere/frontend:${TAG}"
echo ""
echo "If you are using kubeadm on real VMs (your k8s-master/k8s-worker):"
echo "  Push the images to a registry your nodes can pull from."
echo "  Docker Hub example:"
echo "    docker tag shopsphere/backend:${TAG}  <your-dockerhub-user>/shopsphere-backend:${TAG}"
echo "    docker tag shopsphere/frontend:${TAG} <your-dockerhub-user>/shopsphere-frontend:${TAG}"
echo "    docker push <your-dockerhub-user>/shopsphere-backend:${TAG}"
echo "    docker push <your-dockerhub-user>/shopsphere-frontend:${TAG}"
echo "  Then edit k8s/*/deployment.yaml and change the image: field."
