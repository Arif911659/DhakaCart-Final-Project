#!/bin/bash

# ==========================================
# Apply Prometheus Fix
# ==========================================
# 🇧🇩 এই স্ক্রিপ্ট Prometheus পারমিশন সমস্যা এবং কনফিগারেশন ত্রুটি ঠিক করে।
# 🇺🇸 This script fixes Prometheus permission issues and configuration errors.
#
# Usage: ./apply-prometheus-fix.sh

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BASTION_IP="54.251.183.40"
MASTER1_IP="10.0.10.82"
SSH_KEY_PATH="/home/arif/DhakaCart-03-test/terraform/simple-k8s/dhakacart-k8s-key.pem"
REMOTE_USER="ubuntu"

echo -e "${BLUE}===========================================${NC}"
echo -e "${BLUE}Apply Prometheus Configuration Fix${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""

# Copy updated config to Master-1
echo -e "${YELLOW}📤 Copying updated Prometheus config to Master-1...${NC}"

CONFIG_FILE="/home/arif/DhakaCart-03-test/k8s/monitoring/prometheus/configmap.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}❌ Config file not found: $CONFIG_FILE${NC}"
    exit 1
fi

# Copy to Bastion, then to Master-1
scp -i "$SSH_KEY_PATH" "$CONFIG_FILE" "$REMOTE_USER@$BASTION_IP:/tmp/prometheus-configmap.yaml" > /dev/null 2>&1
ssh -i "$SSH_KEY_PATH" "$REMOTE_USER@$BASTION_IP" "scp -i ~/.ssh/dhakacart-k8s-key.pem /tmp/prometheus-configmap.yaml $REMOTE_USER@$MASTER1_IP:/tmp/prometheus-configmap.yaml" > /dev/null 2>&1

echo -e "${GREEN}✅ Config copied${NC}"
echo ""

# Apply on Master-1
echo -e "${YELLOW}📝 Applying Prometheus configuration...${NC}"

ssh -i "$SSH_KEY_PATH" "$REMOTE_USER@$BASTION_IP" "ssh -i ~/.ssh/dhakacart-k8s-key.pem -o StrictHostKeyChecking=no $REMOTE_USER@$MASTER1_IP" << 'EOF'
set -e

# Apply config
kubectl apply -f /tmp/prometheus-configmap.yaml

# Restart Prometheus to pick up new config
echo "Restarting Prometheus deployment..."
kubectl rollout restart deployment/prometheus-deployment -n monitoring

# Wait for rollout
echo "Waiting for Prometheus to restart..."
kubectl rollout status deployment/prometheus-deployment -n monitoring --timeout=120s

# Verify pod is running
echo ""
echo "Prometheus pod status:"
kubectl get pods -n monitoring -l app=prometheus-server

# Cleanup
rm -f /tmp/prometheus-configmap.yaml
EOF

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Error applying fix${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Prometheus configuration updated!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Wait 30-60 seconds for Prometheus to reload config"
echo "  2. Check Prometheus targets:"
echo "     kubectl port-forward -n monitoring svc/prometheus-service 9090:9090"
echo "     Then open: http://localhost:9090/prometheus/targets"
echo "  3. Verify in Grafana dashboard"
echo ""

