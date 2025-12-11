#!/bin/bash

# Infrastructure Configuration Loader
# This script loads infrastructure variables from Terraform outputs
# Source this script in other scripts to get auto-resolved variables
#
# 🇧🇩 এই স্ক্রিপ্ট Terraform থেকে অটোমেটিক IP, DNS এবং অন্যান্য তথ্য ইমপোর্ট করে।
# 🇺🇸 This script automatically imports IPs, DNS, and config from Terraform outputs.

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_config_message() {
    local color=$1
    local message=$2
    echo -e "${color}[CONFIG] ${message}${NC}" >&2
}

# Determine project root and terraform directory
if [ -n "$BASH_SOURCE" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    SCRIPT_DIR="$(pwd)"
fi

PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform/aws-infra"

# Check if terraform directory exists
if [ ! -d "$TERRAFORM_DIR" ]; then
    print_config_message "$RED" "Terraform directory not found: $TERRAFORM_DIR"
    exit 1
fi

# Check if terraform state exists
if [ ! -f "$TERRAFORM_DIR/terraform.tfstate" ]; then
    print_config_message "$RED" "Terraform state not found. Please run 'terraform apply' first."
    exit 1
fi

# Function to get terraform output
# 🇧🇩 Terraform JSON আউটপুট থেকে নির্দিষ্ট ভ্যালু বের করে আনার ফাংশন
# 🇺🇸 Function to parse specific value from Terraform JSON output
get_terraform_output() {
    local output_name=$1
    local default_value=$2
    
    cd "$TERRAFORM_DIR"
    local value=$(terraform output -json 2>/dev/null | jq -r ".$output_name.value // empty")
    cd - > /dev/null
    
    if [ -z "$value" ] || [ "$value" == "null" ]; then
        if [ -n "$default_value" ]; then
            echo "$default_value"
        else
            echo ""
        fi
    else
        echo "$value"
    fi
}

# Load infrastructure variables
print_config_message "$BLUE" "Loading infrastructure configuration from Terraform..."

# Export Bastion IP
# 🇧🇩 Bastion IP বের করা (SSH করার জন্য লাগবে)
# 🇺🇸 Export Bastion IP (Needed for SSH)
export BASTION_IP=$(get_terraform_output "bastion_public_ip")
if [ -z "$BASTION_IP" ]; then
    print_config_message "$RED" "Failed to get Bastion IP from Terraform outputs"
    exit 1
fi

# Export Master IPs
# Export Master IPs
MASTER_IPS_JSON=$(get_terraform_output "master_private_ips")
if [ -n "$MASTER_IPS_JSON" ]; then
    # Convert JSON array to space-separated string for bash array
    MASTER_IPS_STRING=$(echo "$MASTER_IPS_JSON" | jq -r '.[]')
    export MASTER_IPS=($MASTER_IPS_STRING)
    
    export MASTER1_IP=${MASTER_IPS[0]}
    export MASTER2_IP=${MASTER_IPS[1]}
else
    print_config_message "$RED" "Failed to get Master IPs from Terraform outputs"
    exit 1
fi

# Export Worker IPs
WORKER_IPS_JSON=$(get_terraform_output "worker_private_ips")
if [ -n "$WORKER_IPS_JSON" ]; then
    # Convert JSON array to space-separated string for bash array
    WORKER_IPS_STRING=$(echo "$WORKER_IPS_JSON" | jq -r '.[]')
    export WORKER_IPS=($WORKER_IPS_STRING)
else
    print_config_message "$YELLOW" "No Worker IPs found in Terraform outputs"
fi

# Export ALB DNS
export ALB_DNS=$(get_terraform_output "load_balancer_dns")
if [ -z "$ALB_DNS" ]; then
    print_config_message "$YELLOW" "ALB DNS not found in Terraform outputs"
fi

# Export VPC ID
export VPC_ID=$(get_terraform_output "vpc_id")
if [ -z "$VPC_ID" ]; then
    print_config_message "$YELLOW" "VPC ID not found in Terraform outputs"
fi

# Export SSH key path
export SSH_KEY_NAME=$(get_terraform_output "private_key_path" "dhakacart-k8s-key.pem")
export SSH_KEY_PATH="$TERRAFORM_DIR/$SSH_KEY_NAME"

if [ ! -f "$SSH_KEY_PATH" ]; then
    print_config_message "$RED" "SSH key not found: $SSH_KEY_PATH"
    exit 1
fi

# Export common variables
export REMOTE_USER="ubuntu"
export NAMESPACE="dhakacart"
export CLUSTER_NAME=$(get_terraform_output "cluster_name" "dhakacart-k8s")

# Print loaded configuration
print_config_message "$GREEN" "Configuration loaded successfully!"
print_config_message "$BLUE" "Infrastructure Details:"
echo "  Bastion IP:    $BASTION_IP" >&2
echo "  Master-1 IP:   $MASTER1_IP" >&2
if [ -n "$MASTER2_IP" ]; then
    echo "  Master-2 IP:   $MASTER2_IP" >&2
fi
echo "  Worker Count:  ${#WORKER_IPS[@]}" >&2
echo "  ALB DNS:       $ALB_DNS" >&2
echo "  SSH Key:       $SSH_KEY_NAME" >&2
echo "" >&2

# Validation function that other scripts can call
validate_infrastructure() {
    local errors=0
    
    if [ -z "$BASTION_IP" ]; then
        print_config_message "$RED" "BASTION_IP is not set"
        ((errors++))
    fi
    
    if [ -z "$MASTER1_IP" ]; then
        print_config_message "$RED" "MASTER1_IP is not set"
        ((errors++))
    fi
    
    if [ ! -f "$SSH_KEY_PATH" ]; then
        print_config_message "$RED" "SSH key not found: $SSH_KEY_PATH"
        ((errors++))
    fi
    
    if [ $errors -gt 0 ]; then
        print_config_message "$RED" "Infrastructure validation failed with $errors error(s)"
        return 1
    fi
    
    return 0
}

# Export the validation function
export -f validate_infrastructure
export -f print_config_message

# Mark as loaded
export INFRASTRUCTURE_CONFIG_LOADED=true
