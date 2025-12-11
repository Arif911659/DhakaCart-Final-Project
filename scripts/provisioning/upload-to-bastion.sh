#!/bin/bash

# Upload Files to Bastion Script
# Purpose: Upload .pem key and .sh scripts to Bastion host

# ==========================================
# Upload to Bastion
# ==========================================
# 🇧🇩 এই স্ক্রিপ্ট প্রয়োজনীয় সব ফাইল Bastion সার্ভারে আপলোড করে।
# 🇺🇸 This script uploads all necessary files to the Bastion server.
#
# Usage: ./upload-to-bastion.shost

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATED_DIR="$SCRIPT_DIR/generated"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}📤 Uploading files to Bastion...${NC}"

# Load terraform outputs
if [ ! -f "$SCRIPT_DIR/.terraform-outputs.env" ]; then
    echo -e "${RED}❌ Error: Terraform outputs not found!${NC}"
    echo "Run extract-terraform-outputs.sh first."
    exit 1
fi

source "$SCRIPT_DIR/.terraform-outputs.env"

# Validate key file exists
if [ ! -f "$KEY_FILE_PATH" ]; then
    echo -e "${RED}❌ Error: SSH key file not found: $KEY_FILE_PATH${NC}"
    exit 1
fi

# Check key file permissions
KEY_PERMS=$(stat -c "%a" "$KEY_FILE_PATH" 2>/dev/null || stat -f "%OLp" "$KEY_FILE_PATH" 2>/dev/null)
if [ "$KEY_PERMS" != "400" ] && [ "$KEY_PERMS" != "600" ]; then
    echo -e "${YELLOW}⚠️  Setting SSH key permissions to 400...${NC}"
    chmod 400 "$KEY_FILE_PATH"
fi

# Test Bastion connectivity
echo -e "${GREEN}🔍 Testing Bastion connectivity...${NC}"
if ! ssh -i "$KEY_FILE_PATH" -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@"$BASTION_PUBLIC_IP" "echo 'Connection successful'" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  First connection - accepting host key...${NC}"
    ssh -i "$KEY_FILE_PATH" -o StrictHostKeyChecking=accept-new ubuntu@"$BASTION_PUBLIC_IP" "echo 'Connection successful'" || {
        echo -e "${RED}❌ Error: Cannot connect to Bastion!${NC}"
        echo "Please check:"
        echo "  1. Security groups allow SSH from your IP"
        echo "  2. Bastion IP is correct: $BASTION_PUBLIC_IP"
        echo "  3. Key file is correct: $KEY_FILE_PATH"
        exit 1
    }
fi

echo -e "${GREEN}✅ Bastion connectivity confirmed!${NC}"

# Create directories on Bastion
echo -e "${GREEN}📁 Creating directories on Bastion...${NC}"
ssh -i "$KEY_FILE_PATH" ubuntu@"$BASTION_PUBLIC_IP" "mkdir -p ~/.ssh ~/nodes-config"

# Upload SSH key
echo -e "${GREEN}🔑 Uploading SSH key...${NC}"
ssh -i "$KEY_FILE_PATH" -o StrictHostKeyChecking=no ubuntu@"$BASTION_PUBLIC_IP" "rm -f ~/.ssh/${CLUSTER_NAME}-key.pem"
scp -i "$KEY_FILE_PATH" "$KEY_FILE_PATH" ubuntu@"$BASTION_PUBLIC_IP:~/.ssh/${CLUSTER_NAME}-key.pem" || {
    echo -e "${RED}❌ Error: Failed to upload SSH key!${NC}"
    exit 1
}

# Set key permissions on Bastion
ssh -i "$KEY_FILE_PATH" ubuntu@"$BASTION_PUBLIC_IP" "chmod 400 ~/.ssh/${CLUSTER_NAME}-key.pem"

echo -e "${GREEN}✅ SSH key uploaded and permissions set!${NC}"

# Upload generated scripts
if [ ! -d "$GENERATED_DIR" ]; then
    echo -e "${RED}❌ Error: Generated scripts directory not found!${NC}"
    echo "Run generate-scripts.sh first."
    exit 1
fi

echo -e "${GREEN}📜 Uploading configuration scripts...${NC}"
for script in master-1.sh master-2.sh workers.sh; do
    if [ -f "$GENERATED_DIR/$script" ]; then
        scp -i "$KEY_FILE_PATH" "$GENERATED_DIR/$script" ubuntu@"$BASTION_PUBLIC_IP:~/nodes-config/" || {
            echo -e "${YELLOW}⚠️  Warning: Failed to upload $script${NC}"
            continue
        }
        echo -e "${GREEN}  ✅ Uploaded: $script${NC}"
    else
        echo -e "${YELLOW}⚠️  Warning: $script not found in generated directory${NC}"
    fi
done

# Set executable permissions on Bastion
ssh -i "$KEY_FILE_PATH" ubuntu@"$BASTION_PUBLIC_IP" "chmod +x ~/nodes-config/*.sh 2>/dev/null || true"

echo ""
echo -e "${GREEN}✅ All files uploaded successfully!${NC}"
echo ""
echo "Files on Bastion:"
echo "  ~/.ssh/${CLUSTER_NAME}-key.pem"
echo "  ~/nodes-config/master-1.sh"
echo "  ~/nodes-config/master-2.sh"
echo "  ~/nodes-config/workers.sh"
echo ""
echo -e "${GREEN}📋 Next Steps:${NC}"
echo "  1. SSH to Bastion:"
echo "     ssh -i $KEY_FILE_PATH ubuntu@$BASTION_PUBLIC_IP"
echo ""
echo "  2. On Bastion, SSH to Master-1 and run:"
echo "     ssh -i ~/.ssh/${CLUSTER_NAME}-key.pem ubuntu@$MASTER_1_PRIVATE_IP"
echo "     cd ~/nodes-config && ./master-1.sh"
echo ""

