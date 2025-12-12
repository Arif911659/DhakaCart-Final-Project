#!/bin/bash

# ==========================================
# Update Grafana ALB DNS
# ==========================================
# 🇧🇩 এই স্ক্রিপ্ট Grafana কনফিগারেশনে ALB DNS আপডেট করে।
# 🇺🇸 This script updates the ALB DNS in Grafana configuration.
#
# Usage: ./update-grafana-alb-dns.sh

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Source infrastructure variables
if [ -f "$PROJECT_ROOT/scripts/load-env.sh" ]; then
    source "$PROJECT_ROOT/scripts/load-env.sh"
else
    echo -e "${RED}❌ Infrastructure config loader not found at $PROJECT_ROOT/scripts/load-env.sh${NC}"
    exit 1
fi

echo -e "${BLUE}===========================================${NC}"
echo -e "${BLUE}Update Grafana ALB DNS${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""

# Using ALB DNS from loaded config
if [ -z "$ALB_DNS" ]; then
    echo -e "${RED}❌ Error: ALB DNS not found in loaded configuration${NC}"
    exit 1
fi

LB_DNS=$(echo "$ALB_DNS" | sed 's|http://||' | sed 's|https://||') # Clean just in case
echo -e "${GREEN}✅ ALB DNS: $LB_DNS${NC}"
echo -e "${GREEN}✅ Master-1 IP: $MASTER1_IP${NC}"
echo -e "${GREEN}✅ Bastion IP: $BASTION_IP${NC}"
echo ""

# Update Grafana deployment on Master-1
echo -e "${YELLOW}📝 Updating Grafana deployment...${NC}"

ssh -i "$SSH_KEY_PATH" "$REMOTE_USER@$BASTION_IP" "ssh -i ~/.ssh/dhakacart-k8s-key.pem -o StrictHostKeyChecking=no $REMOTE_USER@$MASTER1_IP" << EOF
set -e

# Get current deployment
kubectl get deployment grafana -n monitoring -o yaml > /tmp/grafana-deployment.yaml

# Update ROOT_URL
sed -i "s|value: \"http://.*/grafana/\"|value: \"http://$LB_DNS/grafana/\"|" /tmp/grafana-deployment.yaml
sed -i "s|UPDATE_WITH_ALB_DNS|$LB_DNS|" /tmp/grafana-deployment.yaml

# Ensure SERVE_FROM_SUB_PATH is true
sed -i 's|GF_SERVER_SERVE_FROM_SUB_PATH.*value: "false"|GF_SERVER_SERVE_FROM_SUB_PATH\\n              value: "true"|' /tmp/grafana-deployment.yaml

# Apply update
kubectl apply -f /tmp/grafana-deployment.yaml

# Restart deployment
kubectl rollout restart deployment/grafana -n monitoring

# Wait for rollout
echo "Waiting for Grafana to restart..."
kubectl rollout status deployment/grafana -n monitoring --timeout=120s

# Verify
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
echo -e "${GREEN}✅ Grafana ALB DNS updated!${NC}"
echo ""
echo -e "${BLUE}Access Grafana at:${NC}"
echo -e "${GREEN}http://$LB_DNS/grafana/${NC}"
echo -e "${YELLOW}Username: admin${NC}"
echo -e "${YELLOW}Password: dhakacart123${NC}"
echo ""

