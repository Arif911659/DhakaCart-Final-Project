#!/bin/bash

# Hostname Change Automation Script
# This script changes the hostname of the system

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to display usage
usage() {
    echo "Usage: $0 [hostname] [OPTIONS]"
    echo ""
    echo "Available hostnames:"
    echo "  1. Bastion"
    echo "  2. Master-1"
    echo "  3. Master-2"
    echo "  4. Worker-1"
    echo "  5. Worker-2"
    echo "  6. Worker-3"
    echo ""
    echo "OPTIONS:"
    echo "  --no-confirm    Skip confirmation prompt (for automation)"
    echo ""
    echo "Example: $0 Master-1"
    echo "Example: $0 Master-1 --no-confirm"
    echo "Or run without arguments for interactive mode"
    exit 1
}

# Function to validate hostname
validate_hostname() {
    local hostname=$1
    local valid_hostnames=("Bastion" "Master-1" "Master-2" "Worker-1" "Worker-2" "Worker-3")
    
    for valid in "${valid_hostnames[@]}"; do
        if [ "$hostname" == "$valid" ]; then
            return 0
        fi
    done
    return 1
}

# Function to change hostname
change_hostname() {
    local new_hostname=$1
    local skip_confirm=${2:-false}
    
    print_message "$BLUE" "========================================="
    print_message "$BLUE" "  Hostname Change Script"
# ==========================================
# Change Hostname (Local)
# ==========================================
# 🇧🇩 এই স্ক্রিপ্ট বর্তমান মেশিনের হোস্টনেম পরিবর্তন করে এবং /etc/hosts ফাইল আপডেট করে।
# 🇺🇸 This script changes the local machine's hostname and updates /etc/hosts.
#
# Usage: ./change-hostname.sh <new-hostname>)
    print_message "$YELLOW" "Current hostname: $current_hostname"
    print_message "$GREEN" "New hostname: $new_hostname"
    echo ""
    
    # Ask for confirmation unless --no-confirm is used
    if [ "$skip_confirm" = false ]; then
        read -p "Do you want to proceed with the hostname change? (yes/no): " confirmation
        
        if [[ ! "$confirmation" =~ ^[Yy][Ee][Ss]$ ]]; then
            print_message "$RED" "Hostname change cancelled."
            exit 0
        fi
    fi
    
    print_message "$BLUE" "Changing hostname..."
    
    # Change hostname using hostnamectl (systemd-based systems)
    if command -v hostnamectl &> /dev/null; then
        sudo hostnamectl set-hostname "$new_hostname"
        print_message "$GREEN" "✓ Hostname changed using hostnamectl"
    else
        # Fallback method for non-systemd systems
        sudo hostname "$new_hostname"
        echo "$new_hostname" | sudo tee /etc/hostname > /dev/null
        print_message "$GREEN" "✓ Hostname changed using hostname command"
    fi
    
    # Update /etc/hosts file
    print_message "$BLUE" "Updating /etc/hosts file..."
    
    # Backup /etc/hosts
    sudo cp /etc/hosts /etc/hosts.backup.$(date +%Y%m%d_%H%M%S)
    
    # Update /etc/hosts
    sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$new_hostname/g" /etc/hosts
    
    # If 127.0.1.1 entry doesn't exist, add it
    if ! grep -q "127.0.1.1" /etc/hosts; then
        echo "127.0.1.1	$new_hostname" | sudo tee -a /etc/hosts > /dev/null
    fi
    
    print_message "$GREEN" "✓ /etc/hosts file updated"
    
    echo ""
    print_message "$GREEN" "========================================="
    print_message "$GREEN" "  Hostname successfully changed!"
    print_message "$GREEN" "========================================="
    echo ""
    print_message "$YELLOW" "New hostname: $(hostname)"
    print_message "$YELLOW" "Note: You may need to restart your terminal or reboot the system for all changes to take effect."
    echo ""
}

# Main script logic
main() {
    # Check if running as root or with sudo
    if [ "$EUID" -ne 0 ] && ! sudo -n true 2>/dev/null; then
        print_message "$RED" "This script requires sudo privileges."
        print_message "$YELLOW" "Please run with sudo or ensure your user has sudo access."
        exit 1
    fi
    
    # Parse arguments
    local skip_confirm=false
    local new_hostname=""
    
    for arg in "$@"; do
        if [ "$arg" = "--no-confirm" ]; then
            skip_confirm=true
        else
            new_hostname="$arg"
        fi
    done
    
    # If hostname provided as argument
    if [ -n "$new_hostname" ]; then
        if validate_hostname "$new_hostname"; then
            change_hostname "$new_hostname" "$skip_confirm"
        else
            print_message "$RED" "Error: Invalid hostname '$new_hostname'"
            echo ""
            usage
        fi
    # Interactive mode
    elif [ $# -eq 0 ]; then
        print_message "$BLUE" "========================================="
        print_message "$BLUE" "  Hostname Change Script (Interactive)"
        print_message "$BLUE" "========================================="
        echo ""
        echo "Select a hostname:"
        echo "  1. Bastion"
        echo "  2. Master-1"
        echo "  3. Master-2"
        echo "  4. Worker-1"
        echo "  5. Worker-2"
        echo "  6. Worker-3"
        echo ""
        read -p "Enter your choice (1-6): " choice
        
        case $choice in
            1) new_hostname="Bastion" ;;
            2) new_hostname="Master-1" ;;
            3) new_hostname="Master-2" ;;
            4) new_hostname="Worker-1" ;;
            5) new_hostname="Worker-2" ;;
            6) new_hostname="Worker-3" ;;
            *)
                print_message "$RED" "Invalid choice!"
                exit 1
                ;;
        esac
        
        change_hostname "$new_hostname" false
    else
        usage
    fi
}

# Run main function
main "$@"
