#!/usr/bin/env bash
set -euo pipefail
NS=shopsphere

hr() { printf '\n=== %s ===\n' "$1"; }

hr "Nodes"
kubectl get nodes -o wide

hr "All resources in $NS"
kubectl get all -n "$NS"

hr "PVCs"
kubectl get pvc -n "$NS"

hr "Ingress"
kubectl get ingress -n "$NS"

hr "HPA"
kubectl get hpa -n "$NS"

hr "PDB"
kubectl get pdb -n "$NS"

hr "NetworkPolicy"
kubectl get networkpolicy -n "$NS" || true

hr "Endpoints"
kubectl get endpoints -n "$NS"

hr "Ingress external IP"
kubectl get svc -n ingress-nginx ingress-nginx-controller 2>/dev/null || echo "(not installed)"

hr "Recent events"
kubectl get events -n "$NS" --sort-by=.lastTimestamp | tail -15
