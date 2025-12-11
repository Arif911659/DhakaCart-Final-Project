#!/bin/bash

# ==========================================
# Update ConfigMap with Load Balancer
# ==========================================
# 🇧🇩 এই স্ক্রিপ্ট Kubernetes ConfigMap এ লোড ব্যালেন্সারের DNS বসিয়ে দেয়।
# 🇺🇸 This script injects the Load Balancer DNS into the Kubernetes ConfigMap.
#
# Usage: ./update-configmap-with-lb.shter-1
# with the current Load Balancer URL
# Usage: ./update-configmap-with-lb.sh [LB_URL]
# ============================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
BASTION_IP="54.255.165.250"
MASTER1_IP="10.0.10.102"
SSH_KEY_PATH="/home/arif/DhakaCart-03-test/terraform/simple-k8s/dhakacart-k8s-key.pem"
REMOTE_USER="ubuntu"

echo -e "${BLUE}===========================================${NC}"
echo -e "${BLUE}Update ConfigMap with Load Balancer URL${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""

# Get Load Balancer URL
if [ -z "$1" ]; then
    echo -e "${YELLOW}Getting Load Balancer URL from Master-1...${NC}"
    LB_URL=$(ssh -i "$SSH_KEY_PATH" "$REMOTE_USER@$BASTION_IP" "ssh -i ~/.ssh/dhakacart-k8s-key.pem $REMOTE_USER@$MASTER1_IP" 'kubectl get ingress -A -o jsonpath="{range .items[*]}{.status.loadBalancer.ingress[0].hostname}{\\n}{end}" 2>/dev/null | head -1 || echo ""')
    
    if [ -z "$LB_URL" ] || [ "$LB_URL" == "" ]; then
        echo -e "${RED}❌ Could not automatically detect Load Balancer URL${NC}"
        echo -e "${YELLOW}Please provide Load Balancer URL manually:${NC}"
        read -p "Load Balancer URL (without http://): " LB_URL
    fi
else
    LB_URL="$1"
fi

# Remove http:// if present
LB_URL=$(echo "$LB_URL" | sed 's|http://||' | sed 's|https://||')

echo -e "${GREEN}✅ Load Balancer URL: $LB_URL${NC}"
echo ""

# Update ConfigMap
echo -e "${YELLOW}Updating ConfigMap on Master-1...${NC}"
ssh -i "$SSH_KEY_PATH" "$REMOTE_USER@$BASTION_IP" "ssh -i ~/.ssh/dhakacart-k8s-key.pem $REMOTE_USER@$MASTER1_IP" << EOF
# Get current ConfigMap
kubectl get configmap dhakacart-config -n dhakacart -o yaml > /tmp/dhakacart-config-update.yaml

# Update REACT_APP_API_URL
sed -i "s|REACT_APP_API_URL:.*|REACT_APP_API_URL: \"http://$LB_URL/api\"|" /tmp/dhakacart-config-update.yaml

# Apply updated ConfigMap
kubectl apply -f /tmp/dhakacart-config-update.yaml

# Cleanup
rm /tmp/dhakacart-config-update.yaml

# Verify
echo ""
echo "Updated ConfigMap:"
kubectl get configmap dhakacart-config -n dhakacart -o jsonpath='{.data.REACT_APP_API_URL}'
echo ""
EOF

echo ""
echo -e "${GREEN}✅ ConfigMap updated${NC}"
echo ""

# Restart frontend
echo -e "${YELLOW}Restarting frontend pods to pick up new config...${NC}"
ssh -i "$SSH_KEY_PATH" "$REMOTE_USER@$BASTION_IP" "ssh -i ~/.ssh/dhakacart-k8s-key.pem $REMOTE_USER@$MASTER1_IP" 'kubectl rollout restart deployment dhakacart-frontend -n dhakacart' > /dev/null 2>&1

echo -e "${GREEN}✅ Frontend pods restarting...${NC}"
echo ""
echo -e "${BLUE}Wait 1-2 minutes, then check:${NC}"
echo "  kubectl get pods -n dhakacart"
echo ""

