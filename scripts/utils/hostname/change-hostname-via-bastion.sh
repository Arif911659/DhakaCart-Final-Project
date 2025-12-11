#!/bin/bash

# Hostname Change Automation via Bastion
# This script changes hostnames on Kubernetes cluster nodes via Bastion host

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
TERRAFORM_DIR="/home/arif/DhakaCart-Final-Project/terraform/aws-infra"
SSH_KEY_NAME="dhakacart-k8s-key.pem"
SSH_KEY_LOCAL="./${SSH_KEY_NAME}"
SSH_KEY_BASTION="~/.ssh/${SSH_KEY_NAME}"
SSH_USER="ubuntu"
DRY_RUN=false
FORCE_YES=false

# Function to print colored messages
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to print section header
print_header() {
    local message=$1
    echo ""
    print_message "$BLUE" "========================================="
    print_message "$BLUE" "  $message"
    print_message "$BLUE" "========================================="
    echo ""
}

# ==========================================
# Change Hostname via Bastion
# ==========================================
# 🇧🇩 এই স্ক্রিপ্ট Bastion সার্ভার হয়ে অন্য সব নোডের হোস্টনেম পরিবর্তন করে।
# 🇺🇸 This script changes hostnames of internal nodes via Bastion.
#
# Prerequisite: SSH access to Bastion and internal nodes.
# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Automated hostname change for Kubernetes cluster nodes via Bastion.

OPTIONS:
    --all               Change hostnames on all nodes (Bastion, Masters, Workers)
    --bastion           Change hostname on Bastion only
    --masters           Change hostnames on all Master nodes
    --workers           Change hostnames on all Worker nodes
    --node <name>       Change hostname on specific node (e.g., Master-1, Worker-2)
    -y, --yes           Skip confirmation prompts (for automation)
    --dry-run           Show what would be executed without making changes
    -h, --help          Display this help message

EXAMPLES:
    $0                  # Interactive mode
    $0 --all            # Change all hostnames
    $0 --masters        # Change Master nodes only
    $0 --node Master-1  # Change specific node

HOSTNAMES:
    Bastion, Master-1, Master-2, Worker-1, Worker-2, Worker-3

EOF
    exit 1
}

# Function to check prerequisites
check_prerequisites() {
    print_message "$CYAN" "Checking prerequisites..."
    
    # Check if terraform directory exists
    if [ ! -d "$TERRAFORM_DIR" ]; then
        print_message "$RED" "Error: Terraform directory not found: $TERRAFORM_DIR"
        exit 1
    fi
    
    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_message "$RED" "Error: terraform command not found. Please install Terraform."
        exit 1
    fi
    
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        print_message "$RED" "Error: jq command not found. Please install jq."
        print_message "$YELLOW" "Install with: sudo apt-get install jq"
        exit 1
    fi
    
    # Check if SSH key exists locally
    if [ ! -f "$TERRAFORM_DIR/$SSH_KEY_LOCAL" ]; then
        print_message "$RED" "Error: SSH key not found: $TERRAFORM_DIR/$SSH_KEY_LOCAL"
        exit 1
    fi
    
    print_message "$GREEN" "✓ All prerequisites met"
}

# Function to get Terraform outputs
get_terraform_outputs() {
    print_message "$CYAN" "Fetching Terraform outputs..."
    
    cd "$TERRAFORM_DIR"
    
    # Get Bastion public IP
    BASTION_IP=$(terraform output -json | jq -r '.bastion_public_ip.value')
    
    # Get Master private IPs
    MASTER_IPS=($(terraform output -json | jq -r '.master_private_ips.value[]'))
    
    # Get Worker private IPs
    WORKER_IPS=($(terraform output -json | jq -r '.worker_private_ips.value[]'))
    
    cd - > /dev/null
    
    if [ -z "$BASTION_IP" ] || [ "$BASTION_IP" == "null" ]; then
        print_message "$RED" "Error: Could not retrieve Bastion IP from Terraform outputs"
        exit 1
    fi
    
    print_message "$GREEN" "✓ Terraform outputs retrieved successfully"
    print_message "$YELLOW" "  Bastion IP: $BASTION_IP"
    print_message "$YELLOW" "  Masters: ${#MASTER_IPS[@]} nodes"
    print_message "$YELLOW" "  Workers: ${#WORKER_IPS[@]} nodes"
}

# Function to change hostname on Bastion
change_bastion_hostname() {
    local hostname="Bastion"
    
    print_header "Changing Hostname on Bastion"
    
    if [ "$DRY_RUN" = true ]; then
        print_message "$YELLOW" "[DRY RUN] Would change Bastion hostname to: $hostname"
        return 0
    fi
    
    print_message "$CYAN" "Connecting to Bastion ($BASTION_IP)..."
    
    # SSH to Bastion and change hostname
    ssh -i "$TERRAFORM_DIR/$SSH_KEY_LOCAL" -o StrictHostKeyChecking=no "$SSH_USER@$BASTION_IP" << EOF
        set -e
        echo "Current hostname: \$(hostname)"
        echo "Changing hostname to: $hostname"
        
        # Change hostname
        sudo hostnamectl set-hostname $hostname
        
        # Update /etc/hosts
        sudo cp /etc/hosts /etc/hosts.backup.\$(date +%Y%m%d_%H%M%S)
        sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$hostname/g" /etc/hosts
        
        # If 127.0.1.1 entry doesn't exist, add it
        if ! grep -q "127.0.1.1" /etc/hosts; then
            echo "127.0.1.1\t$hostname" | sudo tee -a /etc/hosts > /dev/null
        fi
        
        echo "New hostname: \$(hostname)"
        echo "Hostname change completed successfully!"
EOF
    
    if [ $? -eq 0 ]; then
        print_message "$GREEN" "✓ Bastion hostname changed successfully to: $hostname"
    else
        print_message "$RED" "✗ Failed to change Bastion hostname"
        return 1
    fi
}

# Function to change hostname on a remote node via Bastion
change_remote_hostname() {
    local node_ip=$1
    local hostname=$2
    
    print_header "Changing Hostname on $hostname ($node_ip)"
    
    if [ "$DRY_RUN" = true ]; then
        print_message "$YELLOW" "[DRY RUN] Would change hostname to: $hostname on $node_ip"
        return 0
    fi
    
    print_message "$CYAN" "Connecting to $hostname via Bastion..."
    
    # SSH to Bastion, then SSH to the target node
    ssh -i "$TERRAFORM_DIR/$SSH_KEY_LOCAL" -o StrictHostKeyChecking=no "$SSH_USER@$BASTION_IP" << EOF
        set -e
        echo "Connecting to $node_ip..."
        
        ssh -i $SSH_KEY_BASTION -o StrictHostKeyChecking=no $SSH_USER@$node_ip << 'INNER_EOF'
            set -e
            echo "Current hostname: \$(hostname)"
            echo "Changing hostname to: $hostname"
            
            # Change hostname
            sudo hostnamectl set-hostname $hostname
            
            # Update /etc/hosts
            sudo cp /etc/hosts /etc/hosts.backup.\$(date +%Y%m%d_%H%M%S)
            sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$hostname/g" /etc/hosts
            
            # If 127.0.1.1 entry doesn't exist, add it
            if ! grep -q "127.0.1.1" /etc/hosts; then
                echo "127.0.1.1\t$hostname" | sudo tee -a /etc/hosts > /dev/null
            fi
            
            echo "New hostname: \$(hostname)"
            echo "Hostname change completed successfully!"
INNER_EOF
EOF
    
    if [ $? -eq 0 ]; then
        print_message "$GREEN" "✓ $hostname hostname changed successfully"
    else
        print_message "$RED" "✗ Failed to change $hostname hostname"
        return 1
    fi
}

# Function to change all Master hostnames
change_masters_hostnames() {
    print_header "Changing Hostnames on Master Nodes"
    
    local success_count=0
    local fail_count=0
    
    for i in "${!MASTER_IPS[@]}"; do
        local master_ip="${MASTER_IPS[$i]}"
        local hostname="Master-$((i + 1))"
        
        if change_remote_hostname "$master_ip" "$hostname"; then
            success_count=$((success_count + 1))
        else
            fail_count=$((fail_count + 1))
        fi
        
        echo ""
    done
    
    print_message "$CYAN" "Master nodes summary: $success_count succeeded, $fail_count failed"
}

# Function to change all Worker hostnames
change_workers_hostnames() {
    print_header "Changing Hostnames on Worker Nodes"
    
    local success_count=0
    local fail_count=0
    
    for i in "${!WORKER_IPS[@]}"; do
        local worker_ip="${WORKER_IPS[$i]}"
        local hostname="Worker-$((i + 1))"
        
        if change_remote_hostname "$worker_ip" "$hostname"; then
            success_count=$((success_count + 1))
        else
            fail_count=$((fail_count + 1))
        fi
        
        echo ""
    done
    
    print_message "$CYAN" "Worker nodes summary: $success_count succeeded, $fail_count failed"
}

# Function to change specific node hostname
change_specific_node() {
    local node_name=$1
    
    case $node_name in
        Bastion)
            change_bastion_hostname
            ;;
        Master-*)
            local index=$(echo "$node_name" | grep -oP '\d+')
            local array_index=$((index - 1))
            
            if [ $array_index -lt 0 ] || [ $array_index -ge ${#MASTER_IPS[@]} ]; then
                print_message "$RED" "Error: Invalid master node: $node_name"
                print_message "$YELLOW" "Available masters: Master-1 to Master-${#MASTER_IPS[@]}"
                exit 1
            fi
            
            change_remote_hostname "${MASTER_IPS[$array_index]}" "$node_name"
            ;;
        Worker-*)
            local index=$(echo "$node_name" | grep -oP '\d+')
            local array_index=$((index - 1))
            
            if [ $array_index -lt 0 ] || [ $array_index -ge ${#WORKER_IPS[@]} ]; then
                print_message "$RED" "Error: Invalid worker node: $node_name"
                print_message "$YELLOW" "Available workers: Worker-1 to Worker-${#WORKER_IPS[@]}"
                exit 1
            fi
            
            change_remote_hostname "${WORKER_IPS[$array_index]}" "$node_name"
            ;;
        *)
            print_message "$RED" "Error: Invalid node name: $node_name"
            print_message "$YELLOW" "Valid names: Bastion, Master-1, Master-2, Worker-1, Worker-2, Worker-3"
            exit 1
            ;;
    esac
}

# Function for interactive mode
interactive_mode() {
    print_header "Interactive Hostname Change Mode"
    
    echo "Available nodes:"
    echo "  0. All nodes"
    echo "  1. Bastion"
    
    for i in "${!MASTER_IPS[@]}"; do
        echo "  $((i + 2)). Master-$((i + 1)) (${MASTER_IPS[$i]})"
    done
    
    local worker_start=$((${#MASTER_IPS[@]} + 2))
    for i in "${!WORKER_IPS[@]}"; do
        echo "  $((worker_start + i)). Worker-$((i + 1)) (${WORKER_IPS[$i]})"
    done
    
    echo ""
    read -p "Select node(s) to change hostname (0-$((worker_start + ${#WORKER_IPS[@]} - 1))): " choice
    
    case $choice in
        0)
            read -p "Change hostnames on ALL nodes? (yes/no): " confirm
            if [[ "$confirm" =~ ^[Yy][Ee][Ss]$ ]]; then
                change_bastion_hostname
                change_masters_hostnames
                change_workers_hostnames
            else
                print_message "$YELLOW" "Operation cancelled"
            fi
            ;;
        1)
            change_bastion_hostname
            ;;
        *)
            if [ $choice -ge 2 ] && [ $choice -lt $worker_start ]; then
                local master_index=$((choice - 2))
                change_remote_hostname "${MASTER_IPS[$master_index]}" "Master-$((master_index + 1))"
            elif [ $choice -ge $worker_start ]; then
                local worker_index=$((choice - worker_start))
                change_remote_hostname "${WORKER_IPS[$worker_index]}" "Worker-$((worker_index + 1))"
            else
                print_message "$RED" "Invalid choice"
                exit 1
            fi
            ;;
    esac
}

# Main script logic
main() {
    print_header "Kubernetes Cluster Hostname Change Automation"
    
    # Parse command line arguments
    local mode="interactive"
    local specific_node=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                mode="all"
                shift
                ;;
            --bastion)
                mode="bastion"
                shift
                ;;
            --masters)
                mode="masters"
                shift
                ;;
            --workers)
                mode="workers"
                shift
                ;;
            --node)
                mode="specific"
                specific_node="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                print_message "$YELLOW" "DRY RUN MODE ENABLED - No changes will be made"
                shift
                ;;
            -y|--yes)
                FORCE_YES=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                print_message "$RED" "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    # Check prerequisites
    check_prerequisites
    
    # Get Terraform outputs
    get_terraform_outputs
    
    # Execute based on mode
    case $mode in
        all)
            if [ "$FORCE_YES" = true ]; then
                confirm="yes"
            else
                read -p "Change hostnames on ALL nodes? (yes/no): " confirm
            fi
            
            if [[ "$confirm" =~ ^[Yy][Ee][Ss]$ ]]; then
                change_bastion_hostname
                change_masters_hostnames
                change_workers_hostnames
            else
                print_message "$YELLOW" "Operation cancelled"
            fi
            ;;
        bastion)
            if [ "$FORCE_YES" = true ]; then
               change_bastion_hostname
            else
               read -p "Change Bastion hostname? (yes/no): " confirm
               if [[ "$confirm" =~ ^[Yy][Ee][Ss]$ ]]; then
                 change_bastion_hostname
               fi
            fi
            ;;
        masters)
            if [ "$FORCE_YES" = true ]; then
               change_masters_hostnames
            else
               read -p "Change Masters hostnames? (yes/no): " confirm
               if [[ "$confirm" =~ ^[Yy][Ee][Ss]$ ]]; then
                 change_masters_hostnames
               fi
            fi
            ;;
        workers)
             if [ "$FORCE_YES" = true ]; then
               change_workers_hostnames
            else
               read -p "Change Workers hostnames? (yes/no): " confirm
               if [[ "$confirm" =~ ^[Yy][Ee][Ss]$ ]]; then
                 change_workers_hostnames
               fi
            fi
            ;;
        specific)
            # No confirmation for specific node unless strictly needed
            change_specific_node "$specific_node"
            ;;
        interactive)
            interactive_mode
            ;;
    esac
    
    print_header "Operation Completed"
    
    if [ "$DRY_RUN" = false ]; then
        print_message "$GREEN" "All hostname changes have been applied!"
        print_message "$YELLOW" "Note: You may need to reconnect to see the new hostnames in your terminal prompt."
    else
        print_message "$YELLOW" "Dry run completed. No changes were made."
    fi
}

# Run main function
main "$@"
