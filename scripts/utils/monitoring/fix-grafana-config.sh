#!/bin/bash

# ============================================
# Fix Grafana Configuration Issues
# ============================================
# 🇧🇩 এই স্ক্রিপ্ট Grafana Datasource কনফিগ সঠিক করে (Prometheus URL আপডেট করে)।
# 🇺🇸 This script fixes Grafana Datasource configuration (Updates Prometheus URL).
#
# Usage: ./fix-grafana-config.sh

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform/aws-infra"
BASTION_IP="54.251.183.40"
MASTER1_IP="10.0.10.82"
SSH_KEY_PATH="$TERRAFORM_DIR/dhakacart-k8s-key.pem"
REMOTE_USER="ubuntu"

echo -e "${BLUE}===========================================${NC}"
echo -e "${BLUE}Fix Grafana Configuration${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""

# Get ALB DNS from Terraform
echo -e "${YELLOW}📊 Getting ALB DNS from Terraform...${NC}"
cd "$TERRAFORM_DIR"

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Error: Terraform not found!${NC}"
    exit 1
fi

LB_DNS=$(terraform output -raw load_balancer_dns 2>/dev/null || echo "")
LB_DNS=$(echo "$LB_DNS" | sed 's|http://||' | sed 's|https://||')

if [ -z "$LB_DNS" ]; then
    echo -e "${RED}❌ Error: Could not get ALB DNS${NC}"
    exit 1
fi

echo -e "${GREEN}✅ ALB DNS: $LB_DNS${NC}"
echo ""

# Update Grafana deployment
echo -e "${YELLOW}📝 Updating Grafana deployment with correct ALB DNS and subpath settings...${NC}"

# Update the deployment file
GRAFANA_DEPLOYMENT="$PROJECT_ROOT/k8s/monitoring/grafana/deployment.yaml"

# Backup original
cp "$GRAFANA_DEPLOYMENT" "$GRAFANA_DEPLOYMENT.bak"

# Update ROOT_URL and SERVE_FROM_SUB_PATH
sed -i "s|value: \"http://.*/grafana/\"|value: \"http://$LB_DNS/grafana/\"|" "$GRAFANA_DEPLOYMENT"
sed -i 's|value: "false"|value: "true"|' "$GRAFANA_DEPLOYMENT"

echo -e "${GREEN}✅ Grafana deployment file updated${NC}"
echo ""

# Copy to Master-1 and apply
echo -e "${YELLOW}📤 Copying updated files to Master-1...${NC}"

# Copy deployment file
scp -i "$SSH_KEY_PATH" "$GRAFANA_DEPLOYMENT" "$REMOTE_USER@$BASTION_IP:/tmp/grafana-deployment.yaml" > /dev/null 2>&1

# Apply on Master-1
ssh -i "$SSH_KEY_PATH" "$REMOTE_USER@$BASTION_IP" "ssh -i ~/.ssh/dhakacart-k8s-key.pem -o StrictHostKeyChecking=no $REMOTE_USER@$MASTER1_IP" << EOF
set -e

# Apply updated Grafana deployment
kubectl apply -f /tmp/grafana-deployment.yaml

# Wait for rollout
echo "Waiting for Grafana pod to restart..."
kubectl rollout status deployment/grafana -n monitoring --timeout=120s

# Get pod status
echo ""
echo "Grafana pod status:"
kubectl get pods -n monitoring -l app=grafana

# Cleanup
rm -f /tmp/grafana-deployment.yaml
EOF

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Error updating Grafana${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Grafana configuration updated!${NC}"
echo ""

# Verify Prometheus datasource
echo -e "${YELLOW}🔍 Verifying Prometheus datasource configuration...${NC}"

ssh -i "$SSH_KEY_PATH" "$REMOTE_USER@$BASTION_IP" "ssh -i ~/.ssh/dhakacart-k8s-key.pem -o StrictHostKeyChecking=no $REMOTE_USER@$MASTER1_IP" << 'EOF'
# Check Prometheus service
echo "Prometheus service:"
kubectl get svc prometheus-service -n monitoring

# Check if Prometheus is accessible from Grafana pod
GRAFANA_POD=$(kubectl get pod -n monitoring -l app=grafana -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || echo "")
if [ -n "$GRAFANA_POD" ]; then
    echo ""
    echo "Testing Prometheus connectivity from Grafana pod:"
    kubectl exec -n monitoring $GRAFANA_POD -- wget -q -O- --timeout=5 http://prometheus-service.monitoring.svc.cluster.local:9090/prometheus/-/healthy 2>&1 | head -1 || echo "Connection test failed"
fi

# Check node-exporter pods
echo ""
echo "Node exporter pods:"
kubectl get pods -n monitoring -l app=node-exporter

# Check Prometheus targets (if accessible)
echo ""
echo "Prometheus targets status:"
kubectl exec -n monitoring $(kubectl get pod -n monitoring -l app=prometheus-server -o jsonpath="{.items[0].metadata.name}") -- wget -q -O- http://localhost:9090/prometheus/api/v1/targets 2>/dev/null | grep -o '"health":"[^"]*"' | head -5 || echo "Cannot check targets"
EOF

echo ""
echo -e "${BLUE}===========================================${NC}"
echo -e "${BLUE}✅ Configuration Update Complete!${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "  1. Wait 1-2 minutes for Grafana to restart"
echo "  2. Access Grafana: http://$LB_DNS/grafana/"
echo "  3. Login: admin / dhakacart123"
echo "  4. Import Dashboard ID 315"
echo "  5. If still no data, check Prometheus targets in Grafana"
echo ""

