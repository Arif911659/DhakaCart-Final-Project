#!/bin/bash

# ============================================
# Auto-Update ConfigMap with Load Balancer URL
# ============================================
# Extracts LB URL from Terraform and updates ConfigMap
# Usage: ./update-configmap-auto.sh
# ============================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo -e "${BLUE}Auto-Update ConfigMap with Load Balancer URL${NC}"
echo ""

# Get Load Balancer URL from Terraform
LB_DNS=$(terraform output -raw load_balancer_dns 2>/dev/null || echo "")

if [ -z "$LB_DNS" ]; then
    echo -e "${RED}❌ Error: Could not get Load Balancer DNS${NC}"
    echo -e "${YELLOW}Make sure you're in terraform/simple-k8s directory${NC}"
    echo -e "${YELLOW}And terraform apply has been run${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Load Balancer DNS: $LB_DNS${NC}"
echo ""

# Update ConfigMap file
CONFIGMAP_FILE="$PROJECT_ROOT/k8s/configmaps/app-config.yaml"

if [ ! -f "$CONFIGMAP_FILE" ]; then
    echo -e "${RED}❌ Error: ConfigMap file not found: $CONFIGMAP_FILE${NC}"
    exit 1
fi

# Backup
cp "$CONFIGMAP_FILE" "$CONFIGMAP_FILE.bak"

# Update
sed -i "s|REACT_APP_API_URL:.*|REACT_APP_API_URL: \"http://$LB_DNS/api\"|" "$CONFIGMAP_FILE"

echo -e "${GREEN}✅ ConfigMap file updated${NC}"
echo ""
echo -e "${BLUE}Updated:${NC}"
grep "REACT_APP_API_URL" "$CONFIGMAP_FILE"
echo ""
echo -e "${YELLOW}Next: Copy k8s/ files to Master-1 and apply${NC}"
echo ""

