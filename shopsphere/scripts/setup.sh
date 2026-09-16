#!/usr/bin/env bash
set -euo pipefail

echo "======================================"
echo "  ShopSphere — cluster bootstrap"
echo "======================================"

echo ""
echo ">>> [1/5] Cluster check"
kubectl cluster-info
kubectl get nodes -o wide

echo ""
echo ">>> [2/5] Detecting CNI"
CNI=$(kubectl get pods -n kube-system -o name 2>/dev/null | grep -E 'calico|cilium|weave|antrea' || true)
if [ -z "$CNI" ]; then
  echo "    ⚠  No NetworkPolicy-capable CNI detected."
  echo "       Flannel alone does NOT enforce NetworkPolicy."
  echo "       → k8s/network/ will be SKIPPED by deploy.sh"
  echo "       → Install Calico if you want NetworkPolicy:"
  echo "         kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml"
else
  echo "    ✓ Found: $CNI"
fi

echo ""
echo ">>> [3/5] StorageClass check"
if ! kubectl get storageclass 2>/dev/null | grep -q '(default)'; then
  echo "    ⚠  No default StorageClass. PVCs will stay Pending."
  echo "       Install local-path-provisioner:"
  echo "       kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.28/deploy/local-path-storage.yaml"
  echo "       kubectl patch storageclass local-path -p '{\"metadata\":{\"annotations\":{\"storageclass.kubernetes.io/is-default-class\":\"true\"}}}'"
else
  echo "    ✓ Default StorageClass present:"
  kubectl get storageclass
fi

echo ""
echo ">>> [4/5] Metrics Server"
if kubectl get deployment metrics-server -n kube-system >/dev/null 2>&1; then
  echo "    ✓ Already installed"
else
  echo "    Installing..."
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
  # Lab clusters use self-signed kubelet certs; add --kubelet-insecure-tls
  kubectl patch deployment metrics-server -n kube-system --type=json \
    -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]' || true
  echo "    Waiting for metrics-server..."
  kubectl rollout status deployment/metrics-server -n kube-system --timeout=180s || true
fi

echo ""
echo ">>> [5/5] NGINX Ingress Controller"
if kubectl get deployment ingress-nginx-controller -n ingress-nginx >/dev/null 2>&1; then
  echo "    ✓ Already installed"
else
  echo "    Installing..."
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.2/deploy/static/provider/baremetal/deploy.yaml
  kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=240s || true
fi

echo ""
echo "======================================"
echo "  Setup complete."
echo ""
echo "  Ingress external IP:"
kubectl get svc -n ingress-nginx ingress-nginx-controller 2>/dev/null || echo "  (not ready yet — retry in a minute)"
echo "======================================"
