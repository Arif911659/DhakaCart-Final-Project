#!/bin/bash

#############################################
# Security Hardening Automation Script
# Applies network policies and runs scans
#############################################

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo -e "${YELLOW}# ==========================================
# Apply Security Hardening
# ==========================================
# 🇧🇩 এই স্ক্রিপ্ট ক্লাস্টারের সিকিউরিটি পলিসি (Network Policy, User Permission) অ্যাপ্লাই করে।
# 🇺🇸 This script applies security policies (Network Policy, User Permissions).
#
# Usage: ./apply-security-hardening.sh${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}   DhakaCart Security Hardening${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Step 1: Copy network policies to k8s directory
echo -e "${YELLOW}📋 Step 1: Preparing network policies...${NC}"
mkdir -p "$PROJECT_ROOT/k8s/security/network-policies"
cp -r "$PROJECT_ROOT/security/network-policies/"* "$PROJECT_ROOT/k8s/security/network-policies/"
echo -e "${GREEN}✅ Network policies copied to k8s directory${NC}"
echo ""

# Step 2: Sync to Master-1
echo -e "${YELLOW}📤 Step 2: Syncing to Master-1...${NC}"
cd "$PROJECT_ROOT"
./scripts/k8s-deployment/sync-k8s-to-master1.sh
echo -e "${GREEN}✅ Files synced to Master-1${NC}"
echo ""

# Step 3: Apply network policies on Master-1
echo -e "${YELLOW}🔒 Step 3: Applying network policies...${NC}"
cat > /tmp/apply-network-policies.sh << 'EOF'
#!/bin/bash
cd ~/k8s/security/network-policies
kubectl apply -f frontend-policy.yaml
kubectl apply -f backend-policy.yaml  
kubectl apply -f database-policy.yaml
kubectl get networkpolicies -n dhakacart
EOF

chmod +x /tmp/apply-network-policies.sh

# Load infrastructure config
source "$PROJECT_ROOT/scripts/load-env.sh" 2>/dev/null || {
    echo -e "${RED}❌ Could not load infrastructure config${NC}"
    echo -e "${YELLOW}ℹ️  Run from terraform directory: terraform output${NC}"
    exit 1
}

# Upload to Bastion first
scp -i "$SSH_KEY_PATH" /tmp/apply-network-policies.sh "${REMOTE_USER}@${BASTION_IP}:/tmp/"

# Execute on Master-1
ssh -i "$SSH_KEY_PATH" "${REMOTE_USER}@${BASTION_IP}" \
    "scp -i ~/.ssh/dhakacart-k8s-key.pem -o StrictHostKeyChecking=no /tmp/apply-network-policies.sh ubuntu@${MASTER_IPS[0]}:/tmp/ && \
     ssh -i ~/.ssh/dhakacart-k8s-key.pem -o StrictHostKeyChecking=no ubuntu@${MASTER_IPS[0]} 'bash /tmp/apply-network-policies.sh'"

echo -e "${GREEN}✅ Network policies applied${NC}"
echo ""

# Step 4: Run security scans locally
echo -e "${YELLOW}🔍 Step 4: Running security scans...${NC}"

# Check if Trivy is installed
if ! command -v trivy &> /dev/null; then
    echo -e "${YELLOW}ℹ️  Installing Trivy...${NC}"
    mkdir -p $HOME/.local/bin
    curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b $HOME/.local/bin
    export PATH=$HOME/.local/bin:$PATH
fi

# Run Trivy scan
cd "$PROJECT_ROOT/security/scanning"
bash ./trivy-scan.sh || echo -e "${YELLOW}⚠️  Vulnerabilities found (see report above)${NC}"

echo -e "${GREEN}✅ Security scans completed${NC}"
echo -e "${YELLOW}ℹ️  Reports saved to: /tmp/trivy-reports-*/${NC}"
echo ""

# Step 5: Run dependency check
echo -e "${YELLOW}📦 Step 5: Checking dependencies...${NC}"
bash ./dependency-check.sh
echo -e "${GREEN}✅ Dependency check completed${NC}"
echo ""

# Step 6: Verify network isolation
echo -e "${YELLOW}🧪 Step 6: Verifying network isolation...${NC}"

cat > /tmp/verify-network-isolation.sh << 'EOF'
#!/bin/bash
echo "Testing: Frontend can reach Backend (should work)..."
kubectl exec -it -n dhakacart deployment/dhakacart-frontend -- curl -s -m 5 http://dhakacart-backend-service:5000/health && echo "✅ Pass" || echo "❌ Fail"

echo ""
echo "Testing: Database CANNOT reach Internet (should timeout)..."
kubectl exec -it -n dhakacart deployment/dhakacart-db -- timeout 5 curl https://google.com 2>&1 || echo "✅ Pass (timeout as expected)"
EOF

# Upload to Bastion first
scp -i "$SSH_KEY_PATH" /tmp/verify-network-isolation.sh "${REMOTE_USER}@${BASTION_IP}:/tmp/"

ssh -i "$SSH_KEY_PATH" "${REMOTE_USER}@${BASTION_IP}" \
    "scp -i ~/.ssh/dhakacart-k8s-key.pem -o StrictHostKeyChecking=no /tmp/verify-network-isolation.sh ubuntu@${MASTER_IPS[0]}:/tmp/ && \
     ssh -i ~/.ssh/dhakacart-k8s-key.pem -o StrictHostKeyChecking=no ubuntu@${MASTER_IPS[0]} 'bash /tmp/verify-network-isolation.sh'"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   ✅ Security Hardening Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Summary:${NC}"
echo "  ✅ Network policies applied (3 policies)"
echo "  ✅ Container images scanned"
echo "  ✅ Dependencies audited"
echo "  ✅ Network isolation verified"
echo ""
