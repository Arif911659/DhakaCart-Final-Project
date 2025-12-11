#!/bin/bash

# ============================================
# DhakaCart - Sync k8s files to Master-1
# ============================================
# Simple script to copy k8s folder to Master-1
# Usage: ./sync-k8s-to-master1.sh
#
# 🇧🇩 এই স্ক্রিপ্ট আপনার লোকাল পিসি থেকে কোড (manifests) মাস্টার নোডে পাঠাবে।
# 🇺🇸 This script syncs your local k8s manifests to the Master node.
# ============================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load infrastructure config
source "$PROJECT_ROOT/scripts/load-env.sh"

BASTION_IP="$BASTION_IP"
MASTER1_IP="${MASTER_IPS[0]}"
SSH_KEY_PATH="$PROJECT_ROOT/terraform/aws-infra/dhakacart-k8s-key.pem"
REMOTE_USER="ubuntu"

echo -e "${BLUE}===========================================${NC}"
echo -e "${BLUE}Syncing k8s/ folder to Master-1${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""

# Copy to Bastion
# 🇧🇩 প্রথমে ফাইলগুলো Bastion (Jump Host) এ কপি করা হয়
# 🇺🇸 Step 1: Copy files to Bastion (Jump Host) first
echo -e "${YELLOW}Copying to Bastion...${NC}"
scp -r -i "$SSH_KEY_PATH" k8s/ scripts/ "$REMOTE_USER@$BASTION_IP:/tmp/" > /dev/null 2>&1
echo -e "${GREEN}✅ Copied to Bastion${NC}"

# Copy database folder to Bastion
echo -e "${YELLOW}Copying database scripts to Bastion...${NC}"
scp -r -i "$SSH_KEY_PATH" database/ "$REMOTE_USER@$BASTION_IP:/tmp/" > /dev/null 2>&1
echo -e "${GREEN}✅ Copied database to Bastion${NC}"

# Copy from Bastion to Master-1
# 🇧🇩 তারপর Bastion থেকে মাস্টার নোডে ফাইলগুলো পাঠানো হয়
# 🇺🇸 Step 2: Copy from Bastion to Master-1 (Final destination)
echo -e "${YELLOW}Copying to Master-1...${NC}"
ssh -i "$SSH_KEY_PATH" "$REMOTE_USER@$BASTION_IP" "scp -r -i ~/.ssh/dhakacart-k8s-key.pem /tmp/k8s /tmp/database /tmp/scripts $REMOTE_USER@$MASTER1_IP:~/" > /dev/null 2>&1
echo -e "${GREEN}✅ Copied to Master-1${NC}"

# Cleanup
ssh -i "$SSH_KEY_PATH" "$REMOTE_USER@$BASTION_IP" "rm -rf /tmp/k8s /tmp/database /tmp/scripts" > /dev/null 2>&1

echo ""
echo -e "${GREEN}===========================================${NC}"
echo -e "${GREEN}✅ Sync Complete!${NC}"
echo -e "${GREEN}===========================================${NC}"
echo ""
echo -e "${BLUE}Next Steps on Master-1:${NC}"
echo "  1. SSH to Master-1"
echo "  2. Run: kubectl apply -f ~/k8s/..."
echo ""

