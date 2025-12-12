#!/bin/bash

# ============================================
# Diagnose Database Products Issue
# ============================================
# 🇧🇩 এই স্ক্রিপ্ট ডাটাবেসে প্রোডাক্ট টেবিল চেক করে এবং সমস্যা থাকলে রিপোর্ট করে।
# 🇺🇸 This script checks the products table in the database and reports issues.
#
# Usage: ./diagnose-db-products-issue.sh

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
# Load infrastructure config
source "$PROJECT_ROOT/scripts/load-env.sh"

echo -e "${BLUE}===========================================${NC}"
echo -e "${BLUE}Database Products Diagnostic Tool${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""

# Check SSH connection
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo -e "${RED}❌ SSH key not found: $SSH_KEY_PATH${NC}"
    exit 1
fi

echo -e "${YELLOW}📊 Running diagnostics on Master-1...${NC}"
echo ""

# Run diagnostics on Master-1
ssh -i "$SSH_KEY_PATH" "$REMOTE_USER@$BASTION_IP" "ssh -i ~/.ssh/dhakacart-k8s-key.pem -o StrictHostKeyChecking=no $REMOTE_USER@$MASTER1_IP" << 'EOF'
set -e

# Colors for remote
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="dhakacart"

echo -e "${BLUE}1. Checking Database Pod Status...${NC}"
DB_POD=$(kubectl get pod -l app=dhakacart-db -n $NAMESPACE -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || echo "")
if [ -z "$DB_POD" ]; then
    echo -e "${RED}❌ Database pod not found!${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Database pod: $DB_POD${NC}"
echo ""

echo -e "${BLUE}2. Checking Database Connection...${NC}"
DB_STATUS=$(kubectl exec -n $NAMESPACE $DB_POD -- pg_isready -U dhakacart 2>&1 || echo "failed")
if echo "$DB_STATUS" | grep -q "accepting connections"; then
    echo -e "${GREEN}✅ Database is ready${NC}"
else
    echo -e "${RED}❌ Database not ready: $DB_STATUS${NC}"
fi
echo ""

echo -e "${BLUE}3. Checking if products table exists...${NC}"
TABLE_EXISTS=$(kubectl exec -n $NAMESPACE $DB_POD -- psql -U dhakacart -d dhakacart_db -t -c "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'products');" 2>/dev/null | tr -d '[:space:]' || echo "false")
if [ "$TABLE_EXISTS" = "t" ]; then
    echo -e "${GREEN}✅ Products table exists${NC}"
else
    echo -e "${RED}❌ Products table does not exist!${NC}"
    echo -e "${YELLOW}   Database needs initialization${NC}"
fi
echo ""

echo -e "${BLUE}4. Counting products in database...${NC}"
PRODUCT_COUNT=$(kubectl exec -n $NAMESPACE $DB_POD -- psql -U dhakacart -d dhakacart_db -t -c "SELECT COUNT(*) FROM products;" 2>/dev/null | tr -d '[:space:]' || echo "0")
if [ "$PRODUCT_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✅ Products found: $PRODUCT_COUNT${NC}"
else
    echo -e "${RED}❌ No products in database!${NC}"
    echo -e "${YELLOW}   Database needs to be seeded${NC}"
fi
echo ""

if [ "$PRODUCT_COUNT" -gt 0 ]; then
    echo -e "${BLUE}5. Sample products (first 3)...${NC}"
    kubectl exec -n $NAMESPACE $DB_POD -- psql -U dhakacart -d dhakacart_db -c "SELECT id, name, price, category, stock FROM products LIMIT 3;" 2>/dev/null || echo "Error fetching products"
    echo ""
fi

echo -e "${BLUE}6. Checking Backend Pods...${NC}"
BACKEND_PODS=$(kubectl get pods -n $NAMESPACE -l app=dhakacart-backend -o jsonpath="{.items[*].metadata.name}" 2>/dev/null || echo "")
if [ -z "$BACKEND_PODS" ]; then
    echo -e "${RED}❌ No backend pods found!${NC}"
else
    echo -e "${GREEN}✅ Backend pods:${NC}"
    for POD in $BACKEND_PODS; do
        STATUS=$(kubectl get pod $POD -n $NAMESPACE -o jsonpath="{.status.phase}" 2>/dev/null || echo "Unknown")
        echo "   - $POD: $STATUS"
    done
fi
echo ""

if [ -n "$BACKEND_PODS" ]; then
    echo -e "${BLUE}7. Checking Backend Logs (last 20 lines)...${NC}"
    FIRST_POD=$(echo $BACKEND_PODS | awk '{print $1}')
    echo -e "${YELLOW}   Pod: $FIRST_POD${NC}"
    kubectl logs -n $NAMESPACE $FIRST_POD --tail=20 2>&1 | head -20 || echo "Error fetching logs"
    echo ""
fi

echo -e "${BLUE}8. Testing Backend API from inside cluster...${NC}"
BACKEND_SVC="dhakacart-backend-service"
API_TEST=$(kubectl run -i --rm --restart=Never test-api-$$ --image=curlimages/curl:latest -n $NAMESPACE -- curl -s -o /dev/null -w "%{http_code}" http://$BACKEND_SVC:5000/api/products 2>/dev/null || echo "000")
if [ "$API_TEST" = "200" ]; then
    echo -e "${GREEN}✅ Backend API is responding (HTTP 200)${NC}"
elif [ "$API_TEST" = "000" ]; then
    echo -e "${RED}❌ Could not test API (connection failed)${NC}"
else
    echo -e "${YELLOW}⚠️  Backend API returned HTTP $API_TEST${NC}"
fi
echo ""

echo -e "${BLUE}9. Checking Frontend ConfigMap...${NC}"
API_URL=$(kubectl get configmap dhakacart-config -n $NAMESPACE -o jsonpath='{.data.REACT_APP_API_URL}' 2>/dev/null || echo "")
if [ -n "$API_URL" ]; then
    echo -e "${GREEN}✅ Frontend API URL: $API_URL${NC}"
    if echo "$API_URL" | grep -q "UPDATE_WITH_CURRENT_ALB_DNS\|PLACEHOLDER"; then
        echo -e "${RED}❌ ConfigMap has placeholder URL!${NC}"
        echo -e "${YELLOW}   Run: ./scripts/update-alb-dns-dynamic.sh${NC}"
    fi
else
    echo -e "${RED}❌ REACT_APP_API_URL not found in ConfigMap!${NC}"
fi
echo ""

echo -e "${BLUE}10. Checking Frontend Pods...${NC}"
FRONTEND_PODS=$(kubectl get pods -n $NAMESPACE -l app=dhakacart-frontend -o jsonpath="{.items[*].metadata.name}" 2>/dev/null || echo "")
if [ -z "$FRONTEND_PODS" ]; then
    echo -e "${RED}❌ No frontend pods found!${NC}"
else
    echo -e "${GREEN}✅ Frontend pods:${NC}"
    for POD in $FRONTEND_PODS; do
        STATUS=$(kubectl get pod $POD -n $NAMESPACE -o jsonpath="{.status.phase}" 2>/dev/null || echo "Unknown")
        echo "   - $POD: $STATUS"
    done
fi
echo ""

# Summary
echo -e "${BLUE}===========================================${NC}"
echo -e "${BLUE}Diagnostic Summary${NC}"
echo -e "${BLUE}===========================================${NC}"

if [ "$TABLE_EXISTS" != "t" ]; then
    echo -e "${RED}❌ CRITICAL: Products table does not exist${NC}"
    echo -e "${YELLOW}   Action: Initialize database${NC}"
elif [ "$PRODUCT_COUNT" -eq 0 ]; then
    echo -e "${RED}❌ CRITICAL: No products in database${NC}"
    echo -e "${YELLOW}   Action: Seed database with products${NC}"
else
    echo -e "${GREEN}✅ Database has products${NC}"
fi

if echo "$API_URL" | grep -q "UPDATE_WITH_CURRENT_ALB_DNS\|PLACEHOLDER"; then
    echo -e "${RED}❌ CRITICAL: ConfigMap has placeholder URL${NC}"
    echo -e "${YELLOW}   Action: Update ALB DNS${NC}"
fi

echo ""
EOF

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Diagnostic failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Diagnostic complete!${NC}"
echo ""
echo -e "${YELLOW}Next steps based on results:${NC}"
echo "  1. If no products: Run database seed script"
echo "  2. If ConfigMap has placeholder: Run update-alb-dns-dynamic.sh"
echo "  3. Check backend logs for connection errors"
echo ""

