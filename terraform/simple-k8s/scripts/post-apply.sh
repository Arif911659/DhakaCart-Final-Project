#!/bin/bash

# ============================================
# Post-Terraform Apply Automation Script
# ============================================
# This script runs after terraform apply to:
# 1. Extract Load Balancer URL from Terraform outputs
# 2. Update k8s/configmaps/app-config.yaml
# 3. Copy k8s/ files to Master-1
# 4. Apply k8s manifests
# 5. Update ConfigMap on cluster
# 6. Restart frontend pods
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BASTION_IP=$(terraform output -raw bastion_public_ip 2>/dev/null || echo "")
MASTER1_IP=$(terraform output -raw master_private_ips 2>/dev/null | head -1 || echo "")
SSH_KEY_PATH="$SCRIPT_DIR/$(terraform output -raw cluster_name 2>/dev/null || echo "dhakacart-k8s")-key.pem"
REMOTE_USER="ubuntu"

echo -e "${BLUE}===========================================${NC}"
echo -e "${BLUE}Post-Terraform Apply Automation${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""

# Step 1: Get Load Balancer URL
echo -e "${YELLOW}[Step 1] Extracting Load Balancer URL...${NC}"
LB_DNS=$(terraform output -raw load_balancer_dns 2>/dev/null || echo "")

if [ -z "$LB_DNS" ]; then
    echo -e "${RED}❌ Error: Could not get Load Balancer DNS from Terraform outputs${NC}"
    echo -e "${YELLOW}Please run: terraform output load_balancer_dns${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Load Balancer DNS: $LB_DNS${NC}"
echo ""

# Step 2: Update ConfigMap file
echo -e "${YELLOW}[Step 2] Updating ConfigMap file...${NC}"
CONFIGMAP_FILE="$PROJECT_ROOT/k8s/configmaps/app-config.yaml"

if [ ! -f "$CONFIGMAP_FILE" ]; then
    echo -e "${RED}❌ Error: ConfigMap file not found: $CONFIGMAP_FILE${NC}"
    exit 1
fi

# Backup original file
cp "$CONFIGMAP_FILE" "$CONFIGMAP_FILE.bak"

# Update REACT_APP_API_URL
sed -i "s|REACT_APP_API_URL:.*|REACT_APP_API_URL: \"http://$LB_DNS/api\"|" "$CONFIGMAP_FILE"

echo -e "${GREEN}✅ ConfigMap file updated${NC}"
echo ""

# Step 3: Get infrastructure details
echo -e "${YELLOW}[Step 3] Getting infrastructure details...${NC}"

if [ -z "$BASTION_IP" ] || [ -z "$MASTER1_IP" ]; then
    echo -e "${RED}❌ Error: Could not get Bastion or Master-1 IP${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Bastion IP: $BASTION_IP${NC}"
echo -e "${GREEN}✅ Master-1 IP: $MASTER1_IP${NC}"
echo ""

# Step 4: Copy k8s files to Master-1
echo -e "${YELLOW}[Step 4] Copying k8s/ files to Master-1...${NC}"

# Check SSH key
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo -e "${RED}❌ Error: SSH key not found: $SSH_KEY_PATH${NC}"
    exit 1
fi

chmod 400 "$SSH_KEY_PATH" 2>/dev/null || true

# Copy to Bastion first
scp -r -i "$SSH_KEY_PATH" "$PROJECT_ROOT/k8s" "$REMOTE_USER@$BASTION_IP:/tmp/" > /dev/null 2>&1

# Copy from Bastion to Master-1
ssh -i "$SSH_KEY_PATH" "$REMOTE_USER@$BASTION_IP" "scp -r -i ~/.ssh/$(basename $SSH_KEY_PATH) /tmp/k8s $REMOTE_USER@$MASTER1_IP:~/k8s" > /dev/null 2>&1

echo -e "${GREEN}✅ Files copied to Master-1${NC}"
echo ""

# Step 5: Apply k8s manifests and update ConfigMap
echo -e "${YELLOW}[Step 5] Applying k8s manifests on Master-1...${NC}"

ssh -i "$SSH_KEY_PATH" "$REMOTE_USER@$BASTION_IP" "ssh -i ~/.ssh/$(basename $SSH_KEY_PATH) $REMOTE_USER@$MASTER1_IP" << EOF
# Apply k8s manifests
kubectl apply -f ~/k8s/namespace.yaml 2>/dev/null || true
kubectl apply -f ~/k8s/secrets/ 2>/dev/null || true
kubectl apply -f ~/k8s/configmaps/ 2>/dev/null || true
kubectl apply -f ~/k8s/volumes/ 2>/dev/null || true
kubectl apply -f ~/k8s/services/ 2>/dev/null || true
kubectl apply -f ~/k8s/deployments/ 2>/dev/null || true

# Update ConfigMap with Load Balancer URL
kubectl get configmap dhakacart-config -n dhakacart -o yaml > /tmp/dhakacart-config.yaml 2>/dev/null || true
sed -i "s|REACT_APP_API_URL:.*|REACT_APP_API_URL: \"http://$LB_DNS/api\"|" /tmp/dhakacart-config.yaml
kubectl apply -f /tmp/dhakacart-config.yaml 2>/dev/null || true
rm /tmp/dhakacart-config.yaml

# Restart frontend pods to pick up new config
kubectl rollout restart deployment dhakacart-frontend -n dhakacart 2>/dev/null || true

echo "Waiting for pods to restart..."
sleep 30

# Check status
kubectl get pods -n dhakacart
kubectl get svc -n dhakacart
EOF

echo -e "${GREEN}✅ k8s manifests applied${NC}"
echo ""

# Step 6: Summary
echo -e "${GREEN}===========================================${NC}"
echo -e "${GREEN}✅ Automation Complete!${NC}"
echo -e "${GREEN}===========================================${NC}"
echo ""
echo -e "${BLUE}Summary:${NC}"
echo -e "  Load Balancer URL: ${YELLOW}http://$LB_DNS${NC}"
echo -e "  Frontend URL: ${YELLOW}http://$LB_DNS${NC}"
echo -e "  Backend API URL: ${YELLOW}http://$LB_DNS/api${NC}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Wait 2-3 minutes for pods to be ready"
echo "  2. Check pods: kubectl get pods -n dhakacart"
echo "  3. Test website: http://$LB_DNS"
echo ""

