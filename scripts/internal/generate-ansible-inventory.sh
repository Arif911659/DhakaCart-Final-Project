#!/bin/bash
set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source infrastructure config
source "$SCRIPT_DIR/load-infrastructure-config.sh"

INVENTORY_FILE="$PROJECT_ROOT/ansible/inventory/hosts.ini"
mkdir -p "$(dirname "$INVENTORY_FILE")"

print_config_message "$BLUE" "Generating Ansible inventory..."

# Create inventory content
cat > "$INVENTORY_FILE" << EOF
# ==========================================
# Generate Ansible Inventory
# ==========================================
# 🇧🇩 এই স্ক্রিপ্ট Terraform আউটপুট থেকে Ansible Inventory ফাইল তৈরি করে।
# 🇺🇸 This script generates an Ansible Inventory file from Terraform outputs.
#
# Usage: ./generate-ansible-inventory.sh
# Generated at: $(date)

[bastion]
bastion-1 ansible_host=$BASTION_IP ansible_user=$REMOTE_USER ansible_ssh_private_key_file=$SSH_KEY_PATH

[masters]
EOF

# Add Masters
count=1
for ip in "${MASTER_IPS[@]}"; do
    echo "master-$count ansible_host=$ip ansible_user=$REMOTE_USER ansible_ssh_common_args='-o ProxyCommand=\"ssh -W %h:%p -q $REMOTE_USER@$BASTION_IP -i $SSH_KEY_PATH\"'" >> "$INVENTORY_FILE"
    ((count++))
done

# Add Workers
cat >> "$INVENTORY_FILE" << EOF

[workers]
EOF

count=1
for ip in "${WORKER_IPS[@]}"; do
    echo "worker-$count ansible_host=$ip ansible_user=$REMOTE_USER ansible_ssh_common_args='-o ProxyCommand=\"ssh -W %h:%p -q $REMOTE_USER@$BASTION_IP -i $SSH_KEY_PATH\"'" >> "$INVENTORY_FILE"
    ((count++))
done

# Add Groups and Vars
cat >> "$INVENTORY_FILE" << EOF

[k8s:children]
masters
workers

[all:vars]
ansible_ssh_private_key_file=$SSH_KEY_PATH
ansible_python_interpreter=/usr/bin/python3
EOF

print_config_message "$GREEN" "Inventory generated at: $INVENTORY_FILE"
cat "$INVENTORY_FILE"
