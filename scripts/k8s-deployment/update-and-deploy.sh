#!/bin/bash

# ==========================================
# Update and Deploy
# ==========================================
# 🇧🇩 এই স্ক্রিপ্ট কোড আপডেট করে এবং নতুন করে অ্যাপ ডিপ্লয় করে।
# 🇺🇸 This script updates code and redeploys the application.
#
# Usage: ./update-and-deploy.sh Copies updated k8s files to Master-1
# 2. Automatically gets Load Balancer URL
# 3. Updates ConfigMap with Load Balancer URL
# 4. Applies all changes
# ============================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BASTION_IP="54.255.165.250"
MASTER1_IP="10.0.10.102"
SSH_KEY_PATH="terraform/simple-k8s/dhakacart-k8s-key.pem"
REMOTE_USER="ubuntu"

echo -e "${BLUE}===========================================${NC}"
echo -e "${BLUE}DhakaCart - Update & Deploy Script${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""

# Step 1: Copy files to Bastion
echo -e "${YELLOW}[Step 1] Copying files to Bastion...${NC}"
scp -i "$SSH_KEY_PATH" -r k8s/ "$REMOTE_USER@$BASTION_IP:/tmp/" > /dev/null 2>&1
echo -e "${GREEN}✅ Files copied to Bastion${NC}"
echo ""

# Step 2: Copy files from Bastion to Master-1
echo -e "${YELLOW}[Step 2] Copying files to Master-1...${NC}"
ssh -i "$SSH_KEY_PATH" "$REMOTE_USER@$BASTION_IP" "scp -r -i ~/.ssh/dhakacart-k8s-key.pem /tmp/k8s $REMOTE_USER@$MASTER1_IP:~/k8s-updated" > /dev/null 2>&1
echo -e "${GREEN}✅ Files copied to Master-1${NC}"
echo ""

# Step 3: Get Load Balancer URL dynamically
echo -e "${YELLOW}[Step 3] Getting Load Balancer URL...${NC}"
LB_URL=$(ssh -i "$SSH_KEY_PATH" "$REMOTE_USER@$BASTION_IP" "ssh -i ~/.ssh/dhakacart-k8s-key.pem $REMOTE_USER@$MASTER1_IP 'kubectl get ingress -n dhakacart -o jsonpath=\"{.items[0].status.loadBalancer.ingress[0].hostname}\" 2>/dev/null || kubectl get svc -n ingress-nginx -o jsonpath=\"{.items[0].status.loadBalancer.ingress[0].hostname}\" 2>/dev/null || echo \"\"'")

if [ -z "$LB_URL" ] || [ "$LB_URL" == "" ]; then
    echo -e "${YELLOW}⚠️  Load Balancer URL not found automatically${NC}"
    echo -e "${BLUE}Please enter Load Balancer URL manually:${NC}"
    read -p "Load Balancer URL: " LB_URL
fi

echo -e "${GREEN}✅ Load Balancer URL: $LB_URL${NC}"
echo ""

# Step 4: Update ConfigMap with Load Balancer URL
echo -e "${YELLOW}[Step 4] Updating ConfigMap on Master-1...${NC}"
ssh -i "$SSH_KEY_PATH" "$REMOTE_USER@$BASTION_IP" "ssh -i ~/.ssh/dhakacart-k8s-key.pem $REMOTE_USER@$MASTER1_IP" << EOF
# Update ConfigMap with Load Balancer URL
kubectl get configmap dhakacart-config -n dhakacart -o yaml > /tmp/dhakacart-config.yaml
sed -i "s|REACT_APP_API_URL:.*|REACT_APP_API_URL: \"http://$LB_URL/api\"|" /tmp/dhakacart-config.yaml
kubectl apply -f /tmp/dhakacart-config.yaml
rm /tmp/dhakacart-config.yaml
EOF

echo -e "${GREEN}✅ ConfigMap updated${NC}"
echo ""

# Step 5: Apply all changes
echo -e "${YELLOW}[Step 5] Applying all changes on Master-1...${NC}"
ssh -i "$SSH_KEY_PATH" "$REMOTE_USER@$BASTION_IP" "ssh -i ~/.ssh/dhakacart-k8s-key.pem $REMOTE_USER@$MASTER1_IP" << EOF
# Apply namespace
kubectl apply -f ~/k8s-updated/namespace.yaml

# Apply secrets
kubectl apply -f ~/k8s-updated/secrets/

# Apply configmaps (already updated with LB URL)
kubectl apply -f ~/k8s-updated/configmaps/

# Apply volumes
kubectl apply -f ~/k8s-updated/volumes/

# Apply services
kubectl apply -f ~/k8s-updated/services/

# Apply deployments
kubectl apply -f ~/k8s-updated/deployments/

# Restart frontend to pick up new ConfigMap
kubectl rollout restart deployment dhakacart-frontend -n dhakacart

echo "Waiting for pods to restart..."
sleep 30

# Check status
kubectl get pods -n dhakacart
kubectl get svc -n dhakacart
EOF

echo -e "${GREEN}✅ All changes applied${NC}"
echo ""

# Step 6: Show summary
echo -e "${GREEN}===========================================${NC}"
echo -e "${GREEN}✅ Deployment Complete!${NC}"
echo -e "${GREEN}===========================================${NC}"
echo ""
echo -e "${BLUE}Summary:${NC}"
echo -e "  - Load Balancer URL: ${YELLOW}$LB_URL${NC}"
echo -e "  - Frontend URL: ${YELLOW}http://$LB_URL${NC}"
echo -e "  - Backend API URL: ${YELLOW}http://$LB_URL/api${NC}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Wait 1-2 minutes for pods to restart"
echo "  2. Check pods: kubectl get pods -n dhakacart"
echo "  3. Test website: http://$LB_URL"
echo ""

