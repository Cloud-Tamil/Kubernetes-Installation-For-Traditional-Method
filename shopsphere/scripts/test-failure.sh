#!/usr/bin/env bash
set -euo pipefail
NS=shopsphere

hr() { printf '\n=== %s ===\n' "$1"; }

hr "Failure 1 — delete a backend pod (K8s recreates it)"
POD=$(kubectl get pods -n "$NS" -l app=shopsphere-backend -o jsonpath='{.items[0].metadata.name}')
echo "Deleting $POD"
kubectl delete pod "$POD" -n "$NS"
sleep 6
kubectl get pods -n "$NS" -l app=shopsphere-backend

hr "Failure 2 — bad image → CrashLoopBackOff → rollback"
echo "Run manually:"
echo "  kubectl set image deployment/shopsphere-backend backend=shopsphere/backend:nonexistent -n $NS"
echo "  kubectl get pods -n $NS"
echo "  kubectl rollout undo deployment/shopsphere-backend -n $NS"

hr "Failure 3 — DNS from a frontend pod to backend"
POD=$(kubectl get pods -n "$NS" -l app=shopsphere-frontend -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n "$NS" "$POD" -- sh -c \
  'wget -qO- http://backend:8080/health/live || echo "backend unreachable"'

hr "Failure 4 — HPA current state"
kubectl get hpa -n "$NS"

hr "Failure 5 — top pods (needs metrics-server)"
kubectl top pods -n "$NS" || echo "(metrics-server not ready)"
