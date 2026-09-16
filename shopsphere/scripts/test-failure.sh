#!/usr/bin/env bash
set -euo pipefail

NS=shopsphere

echo "=== Failure test 1: delete a backend pod ==="
POD=$(kubectl get pods -n $NS -l app=shopsphere-backend -o jsonpath='{.items[0].metadata.name}')
echo "Deleting $POD"
kubectl delete pod $POD -n $NS
sleep 5
kubectl get pods -n $NS -l app=shopsphere-backend

echo ""
echo "=== Failure test 2: bad image (rolls back automatically?) ==="
echo "Run manually: kubectl set image deployment/shopsphere-backend backend=shopsphere/backend:does-not-exist -n $NS"
echo "Then: kubectl rollout undo deployment/shopsphere-backend -n $NS"

echo ""
echo "=== Failure test 3: check service endpoints ==="
kubectl get endpoints -n $NS

echo ""
echo "=== Failure test 4: DNS from a frontend pod ==="
POD=$(kubectl get pods -n $NS -l app=shopsphere-frontend -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n $NS $POD -- sh -c 'wget -qO- http://backend:8080/health/live || echo "backend unreachable"'
