#!/bin/bash

# Fetch Kubeconfig Script
# Retrieves ~/.kube/config from Master-1 via Bastion

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source config loader
if [ -f "$SCRIPT_DIR/load-infrastructure-config.sh" ]; then
    source "$SCRIPT_DIR/load-infrastructure-config.sh"
else
    echo "Error: Config loader not found at $SCRIPT_DIR/load-infrastructure-config.sh"
    exit 1
fi

echo "Fetching kubeconfig from Master-1 ($MASTER1_IP) via Bastion ($BASTION_IP)..."

# SSH Command to fetch config
# Uses -o ProxyCommand or -J (JumpHost) depending on SSH version, but -J is standard now.
# We use the loaded SSH_KEY_PATH

ssh -i "$SSH_KEY_PATH" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ProxyCommand="ssh -i \"$SSH_KEY_PATH\" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -W %h:%p ubuntu@$BASTION_IP" \
    ubuntu@$MASTER1_IP "sudo cat /etc/kubernetes/admin.conf || cat ~/.kube/config" > "$PROJECT_ROOT/kubeconfig_fetched"

if [ -s "$PROJECT_ROOT/kubeconfig_fetched" ]; then
    echo ""
    echo "✅ Kubeconfig successfully fetched!"
    echo ""
    echo "👇 COPY DATA FOR GITHUB SECRETS & VARIABLES 👇"
    echo "==================================================="
    echo "1. Secret Name: KUBECONFIG"
    echo "---------------------------------------------------"
    cat "$PROJECT_ROOT/kubeconfig_fetched"
    echo ""
    echo "---------------------------------------------------"
    echo "2. Secret Name: SSH_PRIVATE_KEY"
    echo "---------------------------------------------------"
    cat "$SSH_KEY_PATH"
    echo ""
    echo "---------------------------------------------------"
    echo "3. Variable Name: BASTION_IP"
    echo "   Value: $BASTION_IP"
    echo "---------------------------------------------------"
    echo "4. Variable Name: MASTER_PRIVATE_IP"
    echo "   Value: $MASTER1_IP"
    echo "==================================================="
    echo "☝️  ADD THESE TO GITHUB ☝️"
    echo ""
    echo "Instructions:"
    echo "1. Go to GitHub Repo -> Settings -> Secrets and variables -> Actions"
    echo "2. Add 'KUBECONFIG' and 'SSH_PRIVATE_KEY' under 'Secrets' -> 'New repository secret'"
    echo "3. Add 'BASTION_IP' and 'MASTER_PRIVATE_IP' under 'Variables' -> 'New repository variable'"
else
    echo "❌ Failed to fetch kubeconfig. File is empty."
    exit 1
fi
