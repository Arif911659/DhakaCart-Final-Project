#!/bin/bash

# ============================================
# Dynamic ALB DNS Update Script
# ============================================
# This script automatically# Update ALB DNS Dynamic
# 🇧🇩 এই স্ক্রিপ্ট অটোমেটিক ALB DNS খুঁজে বের করে এবং কনফিগারেশনে আপডেট করে।
# 🇺🇸 This script automatically finds the ALB DNS and updates the configuration.
#
# Usage: source ./update-alb-dns-dynamic.she ConfigMap in Kubernetes
# Perfect for LAB environments where ALB DNS changes
# ============================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform/simple-k8s"
BASTION_IP="54.251.183.40"
MASTER1_IP="10.0.10.82"
SSH_KEY_PATH="$TERRAFORM_DIR/dhakacart-k8s-key.pem"
REMOTE_USER="ubuntu"
NAMESPACE="dhakacart"
CONFIGMAP_NAME="dhakacart-config"

echo -e "${BLUE}===========================================${NC}"
echo -e "${BLUE}Dynamic ALB DNS Update${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""

# Check if terraform directory exists
if [ ! -d "$TERRAFORM_DIR" ]; then
    echo -e "${RED}❌ Error: Terraform directory not found: $TERRAFORM_DIR${NC}"
    exit 1
fi

# Check if SSH key exists
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo -e "${RED}❌ Error: SSH key not found: $SSH_KEY_PATH${NC}"
    echo -e "${YELLOW}Please ensure the SSH key exists${NC}"
    exit 1
fi

# Get ALB DNS from Terraform output
echo -e "${YELLOW}📊 Getting ALB DNS from Terraform output...${NC}"
cd "$TERRAFORM_DIR"

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Error: Terraform not found!${NC}"
    exit 1
fi

LB_DNS=$(terraform output -raw load_balancer_dns 2>/dev/null || echo "")

if [ -z "$LB_DNS" ] || [ "$LB_DNS" == "" ]; then
    echo -e "${RED}❌ Error: Could not get ALB DNS from Terraform output${NC}"
    echo -e "${YELLOW}Please run 'terraform apply' first${NC}"
    exit 1
fi

# Remove http:// if present
LB_DNS=$(echo "$LB_DNS" | sed 's|http://||' | sed 's|https://||')

echo -e "${GREEN}✅ ALB DNS: $LB_DNS${NC}"
echo ""

# Verify SSH connection to bastion
echo -e "${YELLOW}🔌 Testing SSH connection to Bastion...${NC}"
if ! ssh -i "$SSH_KEY_PATH" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$REMOTE_USER@$BASTION_IP" "echo 'Connected'" > /dev/null 2>&1; then
    echo -e "${RED}❌ Error: Cannot connect to Bastion ($BASTION_IP)${NC}"
    echo -e "${YELLOW}Please check:${NC}"
    echo "  - Bastion IP is correct"
    echo "  - SSH key path is correct"
    echo "  - Network connectivity"
    exit 1
fi

echo -e "${GREEN}✅ Bastion connection successful${NC}"
echo ""

# Update ConfigMap on Master-1
echo -e "${YELLOW}📝 Updating ConfigMap on Master-1...${NC}"

ssh -i "$SSH_KEY_PATH" "$REMOTE_USER@$BASTION_IP" "ssh -i ~/.ssh/dhakacart-k8s-key.pem -o StrictHostKeyChecking=no $REMOTE_USER@$MASTER1_IP" << EOF
set -e

# Check if ConfigMap exists
if ! kubectl get configmap $CONFIGMAP_NAME -n $NAMESPACE > /dev/null 2>&1; then
    echo "ConfigMap not found, creating new one..."
    exit 1
fi

# Get current ConfigMap
kubectl get configmap $CONFIGMAP_NAME -n $NAMESPACE -o yaml > /tmp/dhakacart-config-update.yaml

# Update REACT_APP_API_URL with new ALB DNS
sed -i "s|REACT_APP_API_URL:.*|REACT_APP_API_URL: \"http://$LB_DNS/api\"|" /tmp/dhakacart-config-update.yaml

# Apply updated ConfigMap
kubectl apply -f /tmp/dhakacart-config-update.yaml

# Verify update
echo ""
echo "Updated ConfigMap:"
kubectl get configmap $CONFIGMAP_NAME -n $NAMESPACE -o jsonpath='{.data.REACT_APP_API_URL}'
echo ""

# Cleanup
rm -f /tmp/dhakacart-config-update.yaml
EOF

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Error updating ConfigMap${NC}"
    exit 1
fi

echo -e "${GREEN}✅ ConfigMap updated successfully!${NC}"
echo ""

# Restart frontend pods to pick up new config
echo -e "${YELLOW}🔄 Restarting frontend pods to apply new configuration...${NC}"
ssh -i "$SSH_KEY_PATH" "$REMOTE_USER@$BASTION_IP" "ssh -i ~/.ssh/dhakacart-k8s-key.pem -o StrictHostKeyChecking=no $REMOTE_USER@$MASTER1_IP" << EOF
kubectl rollout restart deployment dhakacart-frontend -n $NAMESPACE
echo "Frontend pods are restarting..."
kubectl rollout status deployment/dhakacart-frontend -n $NAMESPACE --timeout=120s || echo "Rollout status check timed out"
EOF

echo ""
echo -e "${GREEN}✅ Frontend pods restarting...${NC}"
echo ""

# Summary
echo -e "${BLUE}===========================================${NC}"
echo -e "${BLUE}✅ ALB DNS Update Complete!${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""
echo -e "${GREEN}Updated Configuration:${NC}"
echo "  ALB DNS: $LB_DNS"
echo "  API URL: http://$LB_DNS/api"
echo "  ConfigMap: $CONFIGMAP_NAME"
echo "  Namespace: $NAMESPACE"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Wait 1-2 minutes for pods to restart"
echo "  2. Check pod status:"
echo "     ssh -i $SSH_KEY_PATH $REMOTE_USER@$BASTION_IP"
echo "     ssh -i ~/.ssh/dhakacart-k8s-key.pem $REMOTE_USER@$MASTER1_IP"
echo "     kubectl get pods -n $NAMESPACE"
echo "  3. Test site: http://$LB_DNS"
echo ""

