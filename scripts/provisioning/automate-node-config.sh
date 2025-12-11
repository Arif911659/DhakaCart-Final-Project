#!/bin/bash

# Main Automation Script
# Purpose: Orchestrate the entire automation process

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Banner
echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║   # ==========================================
# Automate Node Configuration
# ==========================================
# 🇧🇩 এই স্ক্রিপ্ট সব নোডের কনফিগারেশন অটোমেট করে (IP বসানো, স্ক্রিপ্ট জেনারেট করা)।
# 🇺🇸 This script automates node configuration (Injects IP, generates scripts).
#
# Usage: ./automate-node-config.shpt       ║"
echo "║                  Version 1.0 - 2025-11-29                  ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Check prerequisites
echo -e "${GREEN}🔍 Checking prerequisites...${NC}"

# Check if terraform is available
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Error: Terraform not found!${NC}"
    exit 1
fi

# Check if we're in the right directory
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")"
if [ ! -f "$TERRAFORM_DIR/main.tf" ]; then
    echo -e "${RED}❌ Error: Terraform directory not found!${NC}"
    echo "Expected: $TERRAFORM_DIR"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed!${NC}"
echo ""

# Step 1: Extract Terraform Outputs
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 1/3: Extracting Terraform Outputs${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
"$SCRIPT_DIR/extract-terraform-outputs.sh" || {
    echo -e "${RED}❌ Failed to extract Terraform outputs!${NC}"
    exit 1
}
echo ""

# Step 2: Generate Scripts
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 2/3: Generating Configuration Scripts${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
"$SCRIPT_DIR/generate-scripts.sh" || {
    echo -e "${RED}❌ Failed to generate scripts!${NC}"
    exit 1
}
echo ""

# Step 3: Upload to Bastion
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Step 3/3: Uploading Files to Bastion${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
"$SCRIPT_DIR/upload-to-bastion.sh" || {
    echo -e "${RED}❌ Failed to upload files to Bastion!${NC}"
    exit 1
}
echo ""

# Load outputs for final summary
source "$SCRIPT_DIR/.terraform-outputs.env"

# Final Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Automation Complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}📋 Summary:${NC}"
echo "  ✅ Terraform outputs extracted"
echo "  ✅ Configuration scripts generated"
echo "  ✅ Files uploaded to Bastion"
echo ""
echo -e "${GREEN}🚀 Next Steps:${NC}"
echo ""
echo "1. SSH to Bastion:"
echo -e "   ${YELLOW}ssh -i $KEY_FILE_PATH ubuntu@$BASTION_PUBLIC_IP${NC}"
echo ""
echo "2. On Bastion, configure Master-1:"
echo -e "   ${YELLOW}ssh -i ~/.ssh/${CLUSTER_NAME}-key.pem ubuntu@$MASTER_1_PRIVATE_IP${NC}"
echo -e "   ${YELLOW}cd ~/nodes-config && ./master-1.sh${NC}"
echo ""
echo "3. After Master-1 init, get join token and configure Master-2:"
echo -e "   ${YELLOW}ssh -i ~/.ssh/${CLUSTER_NAME}-key.pem ubuntu@$MASTER_2_PRIVATE_IP${NC}"
echo -e "   ${YELLOW}cd ~/nodes-config && ./master-2.sh${NC}"
echo ""
echo "4. Configure Worker nodes:"
echo -e "   ${YELLOW}ssh -i ~/.ssh/${CLUSTER_NAME}-key.pem ubuntu@$WORKER_1_PRIVATE_IP${NC}"
echo -e "   ${YELLOW}cd ~/nodes-config && ./workers.sh${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✨ All done! Happy configuring! 🎉${NC}"
echo ""

