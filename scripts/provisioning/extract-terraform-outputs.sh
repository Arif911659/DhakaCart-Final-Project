#!/bin/bash

# ==========================================
# Extract Terraform Outputs
# ==========================================
# 🇧🇩 এই স্ক্রিপ্ট Terraform থেকে আউটপুট নিয়ে .env ফাইলে সেভ করে।
# 🇺🇸 This script extracts Terraform outputs and saves them to a .env file.
#
# Usage: ./extract-terraform-outputs.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform/aws-infra"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔍 Extracting Terraform outputs...${NC}"

# Check if terraform state exists
if [ ! -f "$TERRAFORM_DIR/terraform.tfstate" ]; then
    echo -e "${RED}❌ Error: Terraform state not found!${NC}"
    echo "Please run 'terraform apply' first."
    exit 1
fi

# Change to terraform directory
cd "$TERRAFORM_DIR"

# Extract outputs as JSON
OUTPUT_JSON=$(terraform output -json 2>/dev/null)

if [ -z "$OUTPUT_JSON" ]; then
    echo -e "${RED}❌ Error: Could not extract Terraform outputs!${NC}"
    exit 1
fi

# Extract values using jq (if available) or python
if command -v jq &> /dev/null; then
    # Using jq
    BASTION_IP=$(echo "$OUTPUT_JSON" | jq -r '.bastion_public_ip.value // empty')
    MASTER_IPS=$(echo "$OUTPUT_JSON" | jq -r '.master_private_ips.value[] // empty')
    WORKER_IPS=$(echo "$OUTPUT_JSON" | jq -r '.worker_private_ips.value[] // empty')
    CLUSTER_NAME=$(echo "$OUTPUT_JSON" | jq -r '.private_key_path.value // empty' | sed 's|.*/\([^/]*\)-key\.pem|\1|')
elif command -v python3 &> /dev/null; then
    # Using python3
    BASTION_IP=$(echo "$OUTPUT_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['bastion_public_ip']['value'])" 2>/dev/null || echo "")
    MASTER_IPS=$(echo "$OUTPUT_JSON" | python3 -c "import sys, json; data=json.load(sys.stdin); print(' '.join(data['master_private_ips']['value']))" 2>/dev/null || echo "")
    WORKER_IPS=$(echo "$OUTPUT_JSON" | python3 -c "import sys, json; data=json.load(sys.stdin); print(' '.join(data['worker_private_ips']['value']))" 2>/dev/null || echo "")
    CLUSTER_NAME=$(echo "$OUTPUT_JSON" | python3 -c "import sys, json; path=json.load(sys.stdin)['private_key_path']['value']; print(path.split('/')[-1].replace('-key.pem', ''))" 2>/dev/null || echo "")
else
    echo -e "${RED}❌ Error: jq or python3 required for parsing JSON!${NC}"
    echo "Install jq: sudo apt-get install jq"
    exit 1
fi

# Parse IPs into arrays
MASTER_IP_ARRAY=($MASTER_IPS)
WORKER_IP_ARRAY=($WORKER_IPS)

# Extract individual IPs
MASTER_1_IP="${MASTER_IP_ARRAY[0]}"
MASTER_2_IP="${MASTER_IP_ARRAY[1]}"
WORKER_1_IP="${WORKER_IP_ARRAY[0]}"
WORKER_2_IP="${WORKER_IP_ARRAY[1]}"
WORKER_3_IP="${WORKER_IP_ARRAY[2]}"

# Get cluster name from terraform.tfvars if not found
if [ -z "$CLUSTER_NAME" ]; then
    CLUSTER_NAME=$(grep -E "^cluster_name\s*=" "$TERRAFORM_DIR/terraform.tfvars" 2>/dev/null | sed 's/.*=\s*"\(.*\)".*/\1/' | tr -d ' ' || echo "dhakacart-k8s")
fi

# Get key file path
KEY_FILE="$TERRAFORM_DIR/${CLUSTER_NAME}-key.pem"

# Validate extracted values
if [ -z "$BASTION_IP" ]; then
    echo -e "${RED}❌ Error: Bastion IP not found!${NC}"
    exit 1
fi

if [ -z "$MASTER_1_IP" ]; then
    echo -e "${RED}❌ Error: Master-1 IP not found!${NC}"
    exit 1
fi

# Export variables
export BASTION_PUBLIC_IP="$BASTION_IP"
export MASTER_1_PRIVATE_IP="$MASTER_1_IP"
export MASTER_2_PRIVATE_IP="$MASTER_2_IP"
export WORKER_1_PRIVATE_IP="$WORKER_1_IP"
export WORKER_2_PRIVATE_IP="$WORKER_2_IP"
export WORKER_3_PRIVATE_IP="$WORKER_3_IP"
export CLUSTER_NAME="$CLUSTER_NAME"
export KEY_FILE_PATH="$KEY_FILE"
export KUBERNETES_VERSION="v1.29"

# Display extracted values
echo -e "${GREEN}✅ Terraform outputs extracted successfully!${NC}"
echo ""
echo "Extracted Values:"
echo "  Bastion Public IP: $BASTION_PUBLIC_IP"
echo "  Master-1 Private IP: $MASTER_1_PRIVATE_IP"
echo "  Master-2 Private IP: $MASTER_2_PRIVATE_IP"
echo "  Worker-1 Private IP: $WORKER_1_PRIVATE_IP"
echo "  Worker-2 Private IP: $WORKER_2_PRIVATE_IP"
echo "  Worker-3 Private IP: $WORKER_3_PRIVATE_IP"
echo "  Cluster Name: $CLUSTER_NAME"
echo "  Key File: $KEY_FILE_PATH"
echo "  Kubernetes Version: $KUBERNETES_VERSION"
echo ""

# Save to file for other scripts
OUTPUT_FILE="$SCRIPT_DIR/.terraform-outputs.env"
cat > "$OUTPUT_FILE" <<EOF
# Terraform Outputs - Auto-generated
BASTION_PUBLIC_IP=$BASTION_PUBLIC_IP
MASTER_1_PRIVATE_IP=$MASTER_1_PRIVATE_IP
MASTER_2_PRIVATE_IP=$MASTER_2_PRIVATE_IP
WORKER_1_PRIVATE_IP=$WORKER_1_PRIVATE_IP
WORKER_2_PRIVATE_IP=$WORKER_2_PRIVATE_IP
WORKER_3_PRIVATE_IP=$WORKER_3_PRIVATE_IP
CLUSTER_NAME=$CLUSTER_NAME
KEY_FILE_PATH=$KEY_FILE_PATH
KUBERNETES_VERSION=$KUBERNETES_VERSION
EOF

echo -e "${GREEN}✅ Outputs saved to: $OUTPUT_FILE${NC}"

