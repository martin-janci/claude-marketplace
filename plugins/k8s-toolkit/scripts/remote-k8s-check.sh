#!/usr/bin/env bash
# remote-k8s-check.sh - Check Kubernetes cluster health via SSH
#
# Usage:
#   ./remote-k8s-check.sh <ssh-host> [namespace] [--full]
#
# Examples:
#   ./remote-k8s-check.sh k8s-prod
#   ./remote-k8s-check.sh user@bastion production
#   ./remote-k8s-check.sh k8s-staging default --full

set -euo pipefail

HOST="${1:?Usage: $0 <ssh-host> [namespace] [--full]}"
NS="${2:-default}"
FULL="${3:-}"

# Colors (may not work over SSH, but useful for local output)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Kubernetes Health Check ===${NC}"
echo -e "Host:      ${GREEN}$HOST${NC}"
echo -e "Namespace: ${GREEN}$NS${NC}"
echo -e "Time:      $(date)"
echo ""

# Basic check
ssh -o ConnectTimeout=10 "$HOST" << EOF
echo "--- Cluster Info ---"
kubectl cluster-info 2>/dev/null | head -2 || echo "Could not get cluster info"
echo ""

echo "--- Node Status ---"
kubectl get nodes -o wide 2>/dev/null || echo "Could not get nodes"
echo ""

echo "--- Pod Status ($NS) ---"
kubectl get pods -n $NS -o wide 2>/dev/null || echo "Could not get pods"
echo ""

echo "--- Non-Running Pods ---"
kubectl get pods -n $NS 2>/dev/null | grep -v Running | grep -v Completed | grep -v NAME || echo "All pods running/completed"
echo ""

echo "--- Recent Events ($NS) ---"
kubectl get events -n $NS --sort-by='.lastTimestamp' 2>/dev/null | tail -15 || echo "Could not get events"
echo ""

echo "--- Warning Events ---"
kubectl get events -n $NS --field-selector type=Warning --sort-by='.lastTimestamp' 2>/dev/null | tail -10 || echo "No warnings"
echo ""
EOF

# Full check if requested
if [[ "$FULL" == "--full" ]]; then
    echo -e "${BLUE}--- Extended Diagnostics ---${NC}"
    
    ssh -o ConnectTimeout=10 "$HOST" << EOF
echo "--- Resource Usage ---"
kubectl top nodes 2>/dev/null || echo "Metrics not available"
echo ""
kubectl top pods -n $NS 2>/dev/null || echo "Pod metrics not available"
echo ""

echo "--- Deployments ---"
kubectl get deployments -n $NS -o wide 2>/dev/null || echo "No deployments"
echo ""

echo "--- Services ---"
kubectl get svc -n $NS 2>/dev/null || echo "No services"
echo ""

echo "--- Endpoints ---"
kubectl get endpoints -n $NS 2>/dev/null || echo "No endpoints"
echo ""

echo "--- PVCs ---"
kubectl get pvc -n $NS 2>/dev/null || echo "No PVCs"
echo ""

echo "--- ConfigMaps ---"
kubectl get configmaps -n $NS 2>/dev/null | head -20 || echo "No configmaps"
echo ""

echo "--- Secrets (names only) ---"
kubectl get secrets -n $NS 2>/dev/null | head -20 || echo "No secrets"
echo ""

echo "--- Resource Quotas ---"
kubectl describe resourcequota -n $NS 2>/dev/null || echo "No resource quotas"
echo ""

echo "--- Ingresses ---"
kubectl get ingress -n $NS 2>/dev/null || echo "No ingresses"
echo ""
EOF
fi

echo -e "${GREEN}=== Check Complete ===${NC}"
