#!/bin/bash

# ============================================
# Seed Database with Products
# ============================================
#
# 🇧🇩 এই স্ক্রিপ্ট ডাটাবেসে স্যাম্পল প্রোডাক্ট এবং ইউজার ডাটা ইনসার্ট করবে।
# 🇺🇸 This script populates the database with sample products and users.

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# Load infrastructure config
source "$PROJECT_ROOT/load-infrastructure-config.sh"

BASTION_IP="$BASTION_IP"
MASTER1_IP="${MASTER_IPS[0]}" # Assuming first master
SSH_KEY_PATH="$SSH_KEY_PATH"
REMOTE_USER="ubuntu"
NAMESPACE="dhakacart"
INIT_SQL="/home/arif/DhakaCart-03-test/database/init.sql"

echo -e "${BLUE}===========================================${NC}"
echo -e "${BLUE}Seed Database with Products${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""


# Check for automation flag
AUTOMATED=false
if [[ "$1" == "--automated" || "$1" == "-y" ]]; then
    AUTOMATED=true
fi

# Check if init.sql exists
if [ ! -f "$INIT_SQL" ]; then
    echo -e "${RED}❌ Error: init.sql not found at $INIT_SQL${NC}"
    exit 1
fi

# Check SSH key
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo -e "${RED}❌ Error: SSH key not found: $SSH_KEY_PATH${NC}"
    exit 1
fi

echo -e "${YELLOW}📊 Connecting to Master-1 to seed database...${NC}"
echo ""

# Copy init.sql to Master-1
# 🇧🇩 SQL ফাইলটি প্রথমে মাস্টারে পাঠানো হয়, কারণ সেখান থেকে কুবারনেটিস কমান্ড চালানো যাবে
# 🇺🇸 Step 1: Copy SQL file to Master node to run kubectl commands
echo -e "${BLUE}Copying init.sql to Bastion...${NC}"
scp -i "$SSH_KEY_PATH" "$INIT_SQL" "$REMOTE_USER@$BASTION_IP:/tmp/init.sql" > /dev/null 2>&1

echo -e "${BLUE}Copying init.sql to Master-1...${NC}"
ssh -i "$SSH_KEY_PATH" "$REMOTE_USER@$BASTION_IP" "scp -i ~/.ssh/dhakacart-k8s-key.pem /tmp/init.sql $REMOTE_USER@$MASTER1_IP:/tmp/init.sql" > /dev/null 2>&1

ssh -i "$SSH_KEY_PATH" "$REMOTE_USER@$BASTION_IP" "ssh -i ~/.ssh/dhakacart-k8s-key.pem -o StrictHostKeyChecking=no $REMOTE_USER@$MASTER1_IP 'bash -s' -- $AUTOMATED" << 'EOF'
set -e
AUTOMATED=$1

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="dhakacart"

# Get DB pod
echo -e "${BLUE}Finding database pod...${NC}"
DB_POD=$(kubectl get pod -l app=dhakacart-db -n $NAMESPACE -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || echo "")

if [ -z "$DB_POD" ]; then
    echo -e "${RED}❌ Database pod not found!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Database pod: $DB_POD${NC}"
echo ""

# Wait for database to be ready
echo -e "${BLUE}Waiting for database to be ready...${NC}"
kubectl wait --for=condition=ready pod/$DB_POD -n $NAMESPACE --timeout=60s
echo ""

# Check if products table exists
echo -e "${BLUE}Checking if products table exists...${NC}"
TABLE_EXISTS=$(kubectl exec -n $NAMESPACE $DB_POD -- psql -U dhakacart -d dhakacart_db -t -c "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'products');" 2>/dev/null | tr -d '[:space:]' || echo "false")

if [ "$TABLE_EXISTS" != "t" ]; then
    echo -e "${YELLOW}Products table does not exist. Creating tables...${NC}"
else
    echo -e "${GREEN}✅ Products table exists${NC}"
fi

# Check product count
PRODUCT_COUNT=$(kubectl exec -n $NAMESPACE $DB_POD -- psql -U dhakacart -d dhakacart_db -t -c "SELECT COUNT(*) FROM products;" 2>/dev/null | tr -d '[:space:]' || echo "0")

if [ "$PRODUCT_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Database already has $PRODUCT_COUNT products${NC}"
    echo -e "${YELLOW}Do you want to re-seed? This will:${NC}"
    echo -e "${YELLOW}  1. Drop existing tables (if needed)${NC}"
    echo -e "${YELLOW}  2. Recreate tables${NC}"
    echo -e "${YELLOW}  3. Insert sample products${NC}"
    echo ""
    if [ "$AUTOMATED" = true ]; then
        echo -e "${GREEN}✅ Database already seeded. Skipping...${NC}"
        exit 0
    else
        read -p "Continue? (y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}Operation cancelled${NC}"
            exit 0
        fi
    fi
    
    # Drop tables
    echo -e "${YELLOW}Dropping existing tables...${NC}"
    kubectl exec -n $NAMESPACE $DB_POD -- psql -U dhakacart -d dhakacart_db << 'SQL'
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS products CASCADE;
SQL
    echo -e "${GREEN}✅ Tables dropped${NC}"
fi

# Execute init.sql
# 🇧🇩 পডের ভেতরে psql কমান্ড চালিয়ে ডাটা ইম্পোর্ট করা হচ্ছে
# 🇺🇸 Step 2: Execute SQL inside the database pod using psql
echo -e "${BLUE}Executing init.sql...${NC}"
kubectl exec -i -n $NAMESPACE $DB_POD -- psql -U dhakacart -d dhakacart_db < /tmp/init.sql 2>&1 || {
    # If file doesn't exist, try copying it
    if [ ! -f /tmp/init.sql ]; then
        echo -e "${RED}❌ init.sql not found on Master-1${NC}"
        echo -e "${YELLOW}Please copy init.sql manually${NC}"
        exit 1
    fi
}

echo -e "${GREEN}✅ init.sql executed${NC}"
echo ""

# Verify
echo -e "${BLUE}Verifying database...${NC}"
NEW_COUNT=$(kubectl exec -n $NAMESPACE $DB_POD -- psql -U dhakacart -d dhakacart_db -t -c "SELECT COUNT(*) FROM products;" 2>/dev/null | tr -d '[:space:]' || echo "0")

if [ "$NEW_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✅ Database seeded successfully!${NC}"
    echo -e "${GREEN}   Products count: $NEW_COUNT${NC}"
    echo ""
    echo -e "${BLUE}Sample products:${NC}"
    kubectl exec -n $NAMESPACE $DB_POD -- psql -U dhakacart -d dhakacart_db -c "SELECT id, name, price, category FROM products LIMIT 5;" 2>/dev/null
else
    echo -e "${RED}❌ Database seeding failed!${NC}"
    exit 1
fi

# Clear Redis cache
echo ""
echo -e "${BLUE}Clearing Redis cache...${NC}"
REDIS_POD=$(kubectl get pod -l app=dhakacart-redis -n $NAMESPACE -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || echo "")
if [ -n "$REDIS_POD" ]; then
    kubectl exec -n $NAMESPACE $REDIS_POD -- redis-cli FLUSHALL > /dev/null 2>&1 || true
    echo -e "${GREEN}✅ Redis cache cleared${NC}"
fi

# Restart backend to refresh cache
echo ""
echo -e "${BLUE}Restarting backend pods...${NC}"
kubectl rollout restart deployment/dhakacart-backend -n $NAMESPACE > /dev/null 2>&1
echo -e "${GREEN}✅ Backend pods restarting${NC}"
echo ""

EOF

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Database seeding failed!${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}===========================================${NC}"
echo -e "${GREEN}✅ Database Seeding Complete!${NC}"
echo -e "${GREEN}===========================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Wait 1-2 minutes for backend pods to restart"
echo "  2. Check products: kubectl exec -n dhakacart <db-pod> -- psql -U dhakacart -d dhakacart_db -c 'SELECT COUNT(*) FROM products;'"
echo "  3. Test API: curl http://ALB_DNS/api/products"
echo ""

