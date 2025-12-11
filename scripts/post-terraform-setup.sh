#!/bin/bash

# Post-Terraform Setup Script
#
# 🇧🇩 এই স্ক্রিপ্ট Terraform শেষের পর ইনভেন্টরি তৈরি ও কনফিগ লোড করে।
# 🇺🇸 This script runs after Terraform to generate inventory and load config.
#
# Usage: ./post-terraform-setup.shion script to configure infrastructure after terraform apply

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Print functions
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_header() {
    echo ""
    print_message "$BLUE" "========================================="
    print_message "$BLUE" "  $1"
    print_message "$BLUE" "========================================="
    echo ""
}

print_step() {
    local step=$1
    local total=$2
    local message=$3
    print_message "$CYAN" "[$step/$total] $message"
}

# Confirmation function
confirm() {
    local message=$1
    local default=${2:-n}
    
    if [ "$default" = "y" ]; then
        local prompt="$message [Y/n]: "
    else
        local prompt="$message [y/N]: "
    fi
    
    read -p "$(echo -e ${YELLOW}${prompt}${NC})" response
    response=${response:-$default}
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Main script
main() {
    print_header "DhakaCart Post-Terraform Setup"
    
    print_message "$YELLOW" "This script will help you configure your infrastructure after terraform apply."
    print_message "$YELLOW" "It will guide you through each step with confirmations."
    echo ""
    
    # Step 1: Load infrastructure config
    print_step 1 6 "Loading infrastructure configuration from Terraform..."
    
    if ! source "$SCRIPT_DIR/load-env.sh"; then
        print_message "$RED" "Failed to load infrastructure configuration"
        print_message "$YELLOW" "Please ensure 'terraform apply' has been run successfully"
        exit 1
    fi
    
    print_message "$GREEN" "✓ Configuration loaded"
    echo ""
    
    # Step 2: Validate infrastructure
    print_step 2 6 "Validating infrastructure..."
    
    if ! validate_infrastructure; then
        print_message "$RED" "Infrastructure validation failed"
        exit 1
    fi
    
    print_message "$GREEN" "✓ Infrastructure validated"
    echo ""
    
    # Step 3: Update script variables
    print_step 3 6 "Update all scripts with current infrastructure IPs"
    
    if confirm "Do you want to update all scripts with current IPs?" "y"; then
        print_message "$CYAN" "Updating scripts..."
        
        # List of scripts to update
        local scripts_to_update=(
            "database/seed-database.sh"
            "utils/database/diagnose-db-products-issue.sh"
            "monitoring/apply-prometheus-fix.sh"
            "monitoring/check-prometheus-metrics.sh"
            "monitoring/fix-grafana-config.sh"
            "monitoring/diagnose-grafana-issues.sh"
            "monitoring/fix-promtail-logs.sh"
            "update-alb-dns-dynamic.sh"
            "monitoring/update-grafana-alb-dns.sh"
            "k8s-deployment/update-and-deploy.sh"

            "k8s-deployment/sync-k8s-to-master1.sh"
            "utils/k8s-deployment/update-configmap-with-lb.sh"
        )
        
        local updated_count=0
        for script in "${scripts_to_update[@]}"; do
            local script_path="$SCRIPT_DIR/$script"
            if [ -f "$script_path" ]; then
                # Backup original
                cp "$script_path" "$script_path.backup"
                
                # Update BASTION_IP
                sed -i "s/^BASTION_IP=.*/BASTION_IP=\"$BASTION_IP\"/" "$script_path"
                
                # Update MASTER1_IP
                sed -i "s/^MASTER1_IP=.*/MASTER1_IP=\"$MASTER1_IP\"/" "$script_path"
                
                ((updated_count++))
                print_message "$GREEN" "  ✓ Updated $script"
            else
                print_message "$YELLOW" "  ⚠ Script not found: $script"
            fi
        done
        
        print_message "$GREEN" "✓ Updated $updated_count scripts"
        print_message "$YELLOW" "  Backups saved with .backup extension"
    else
        print_message "$YELLOW" "Skipped script updates"
    fi
    echo ""
    
    # Step 4: Change hostnames
    print_step 4 6 "Change hostnames on cluster nodes"
    
    if confirm "Do you want to change hostnames (Bastion, Master-1/2, Worker-1/2/3)?" "n"; then
        print_message "$CYAN" "Running hostname change script..."
        
        if [ -f "$SCRIPT_DIR/utils/hostname/change-hostname-via-bastion.sh" ]; then
            "$SCRIPT_DIR/utils/hostname/change-hostname-via-bastion.sh"
        else
            print_message "$RED" "Hostname change script not found"
        fi
    else
        print_message "$YELLOW" "Skipped hostname changes"
    fi
    echo ""
    
    # Step 5: Setup Grafana ALB
    print_step 5 6 "Setup Grafana ALB routing"
    
    if confirm "Do you want to setup Grafana ALB routing?" "y"; then
        print_message "$CYAN" "Setting up Grafana ALB..."
        
        if [ -f "$SCRIPT_DIR/monitoring/setup-grafana-alb.sh" ]; then
            "$SCRIPT_DIR/monitoring/setup-grafana-alb.sh"
        else
            print_message "$RED" "Grafana ALB setup script not found"
        fi
    else
        print_message "$YELLOW" "Skipped Grafana ALB setup"
    fi
    echo ""
    
    # Step 6: Summary and next steps
    print_step 6 6 "Setup Summary"
    
    print_header "Setup Complete!"
    
    print_message "$GREEN" "Infrastructure is ready!"
    echo ""
    print_message "$CYAN" "📋 Next Steps:"
    echo ""
    echo "1. Deploy Kubernetes cluster:"
    echo "   cd $SCRIPT_DIR/k8s-deployment"
    echo "   ./update-and-deploy.sh"
    echo ""
    echo "2. Access your application:"
    echo "   Frontend: http://$ALB_DNS"
    echo "   Grafana:  http://$ALB_DNS/grafana/"
    echo ""
    echo "3. Seed database (if needed):"
    echo "   cd $SCRIPT_DIR/database"
    echo "   ./seed-database.sh"
    echo ""
    print_message "$YELLOW" "📚 For detailed deployment steps, see: DEPLOYMENT-GUIDE.md"
    print_message "$YELLOW" "🔧 For troubleshooting, see: docs/TROUBLESHOOTING.md"
    echo ""
}

# Run main function
main "$@"
