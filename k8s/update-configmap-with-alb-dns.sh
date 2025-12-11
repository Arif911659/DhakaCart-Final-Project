#!/bin/bash

# Update ConfigMap with Dynamic ALB DNS
# Purpose: Extract ALB DNS from Terraform and update ConfigMap automatically
# Usage: ./update-configmap-with-alb-dns.sh [ALB_DNS]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform/simple-k8s"
CONFIGMAP_FILE="$SCRIPT_DIR/configmaps/app-config.yaml"
CONFIGMAP_TEMPLATE="$SCRIPT_DIR/configmaps/app-config.yaml.template"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🔄 Updating ConfigMap with ALB DNS...${NC}"

# Function to extract ALB DNS from Terraform
extract_alb_dns() {
    if [ -f "$TERRAFORM_DIR/terraform.tfstate" ]; then
        cd "$TERRAFORM_DIR"
        
        # Try to get from terraform output
        ALB_DNS=$(terraform output -raw load_balancer_dns 2>/dev/null || echo "")
        
        if [ -z "$ALB_DNS" ]; then
            # Try to get from JSON output
            if command -v jq &> /dev/null; then
                ALB_DNS=$(terraform output -json 2>/dev/null | jq -r '.load_balancer_dns.value // empty' || echo "")
            elif command -v python3 &> /dev/null; then
                ALB_DNS=$(terraform output -json 2>/dev/null | python3 -c "import sys, json; print(json.load(sys.stdin).get('load_balancer_dns', {}).get('value', ''))" 2>/dev/null || echo "")
            fi
        fi
        
        cd - > /dev/null
        echo "$ALB_DNS"
    else
        echo ""
    fi
}

# Get ALB DNS
if [ -n "$1" ]; then
    # Use provided DNS
    ALB_DNS="$1"
    echo -e "${GREEN}✅ Using provided ALB DNS: $ALB_DNS${NC}"
else
    # Extract from Terraform
    echo -e "${GREEN}🔍 Extracting ALB DNS from Terraform...${NC}"
    ALB_DNS=$(extract_alb_dns)
    
    if [ -z "$ALB_DNS" ]; then
        echo -e "${RED}❌ Error: Could not extract ALB DNS from Terraform!${NC}"
        echo ""
        echo "Usage:"
        echo "  $0 <ALB_DNS>"
        echo ""
        echo "Example:"
        echo "  $0 dhakacart-k8s-alb-329362090.ap-southeast-1.elb.amazonaws.com"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Extracted ALB DNS: $ALB_DNS${NC}"
fi

# Validate DNS format
if [[ ! "$ALB_DNS" =~ ^[a-zA-Z0-9.-]+\.elb\.amazonaws\.com$ ]] && [[ ! "$ALB_DNS" =~ ^[a-zA-Z0-9.-]+$ ]]; then
    echo -e "${YELLOW}⚠️  Warning: ALB DNS format might be incorrect: $ALB_DNS${NC}"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Update ConfigMap file
echo -e "${GREEN}📝 Updating ConfigMap file...${NC}"

# Create backup
cp "$CONFIGMAP_FILE" "${CONFIGMAP_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

# Update REACT_APP_API_URL
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s|REACT_APP_API_URL:.*|REACT_APP_API_URL: \"http://${ALB_DNS}/api\"|" "$CONFIGMAP_FILE"
else
    # Linux
    sed -i "s|REACT_APP_API_URL:.*|REACT_APP_API_URL: \"http://${ALB_DNS}/api\"|" "$CONFIGMAP_FILE"
fi

echo -e "${GREEN}✅ ConfigMap file updated!${NC}"

# Apply ConfigMap to Kubernetes
echo -e "${GREEN}🚀 Applying ConfigMap to Kubernetes...${NC}"

if kubectl apply -f "$CONFIGMAP_FILE"; then
    echo -e "${GREEN}✅ ConfigMap applied successfully!${NC}"
else
    echo -e "${RED}❌ Error: Failed to apply ConfigMap!${NC}"
    exit 1
fi

# Restart frontend pods to pick up new config
echo -e "${GREEN}🔄 Restarting frontend pods...${NC}"

if kubectl rollout restart deployment/dhakacart-frontend -n dhakacart; then
    echo -e "${GREEN}✅ Frontend deployment restart initiated!${NC}"
    echo ""
    echo -e "${GREEN}📊 Waiting for rollout to complete...${NC}"
    kubectl rollout status deployment/dhakacart-frontend -n dhakacart --timeout=120s
else
    echo -e "${YELLOW}⚠️  Warning: Could not restart frontend deployment${NC}"
    echo "You may need to restart manually:"
    echo "  kubectl rollout restart deployment/dhakacart-frontend -n dhakacart"
fi

echo ""
echo -e "${GREEN}✅ ConfigMap update complete!${NC}"
echo ""
echo "Summary:"
echo "  ALB DNS: $ALB_DNS"
echo "  API URL: http://${ALB_DNS}/api"
echo "  ConfigMap: Updated and applied"
echo "  Frontend: Restarted"
echo ""
echo -e "${GREEN}🎉 Done! Frontend will now use the new ALB DNS.${NC}"

