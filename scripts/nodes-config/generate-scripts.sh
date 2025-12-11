#!/bin/bash

# Generate Scripts from Templates
# Purpose: Replace placeholders in template files with actual values
#
# 🇧🇩 এই স্ক্রিপ্ট টেম্পলেট ফাইল থেকে আসল স্ক্রিপ্ট জেনারেট করে (IP বসিয়ে)।
# 🇺🇸 This script generates final scripts from templates by replacing placeholders.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates"
GENERATED_DIR="$SCRIPT_DIR/generated"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}📝 Generating scripts from templates...${NC}"

# Load terraform outputs
if [ ! -f "$SCRIPT_DIR/.terraform-outputs.env" ]; then
    echo -e "${RED}❌ Error: Terraform outputs not found!${NC}"
    echo "Run extract-terraform-outputs.sh first."
    exit 1
fi

source "$SCRIPT_DIR/.terraform-outputs.env"

# Create directories
mkdir -p "$GENERATED_DIR"
mkdir -p "$TEMPLATES_DIR"

# Function to replace placeholders in template
replace_template() {
    local template_file="$1"
    local output_file="$2"
    
    if [ ! -f "$template_file" ]; then
        echo -e "${YELLOW}⚠️  Template not found: $template_file${NC}"
        echo "Creating from existing script..."
        return 1
    fi
    
    # Read template and replace placeholders
    sed -e "s|{{MASTER_1_IP}}|$MASTER_1_PRIVATE_IP|g" \
        -e "s|{{MASTER_2_IP}}|$MASTER_2_PRIVATE_IP|g" \
        -e "s|{{WORKER_1_IP}}|$WORKER_1_PRIVATE_IP|g" \
        -e "s|{{WORKER_2_IP}}|$WORKER_2_PRIVATE_IP|g" \
        -e "s|{{WORKER_3_IP}}|$WORKER_3_PRIVATE_IP|g" \
        -e "s|{{CLUSTER_NAME}}|$CLUSTER_NAME|g" \
        -e "s|{{KUBERNETES_VERSION}}|$KUBERNETES_VERSION|g" \
        "$template_file" > "$output_file"
    
    chmod +x "$output_file"
    echo -e "${GREEN}✅ Generated: $(basename "$output_file")${NC}"
}

# Generate master-1.sh
if [ -f "$TEMPLATES_DIR/master-1.sh.template" ]; then
    replace_template "$TEMPLATES_DIR/master-1.sh.template" "$GENERATED_DIR/master-1.sh"
else
    echo -e "${YELLOW}⚠️  Template master-1.sh.template not found, creating from existing...${NC}"
    # Create template from existing script if template doesn't exist
    if [ -f "$SCRIPT_DIR/master-1.sh" ]; then
        sed -e "s|10\.0\.10\.[0-9]*|{{MASTER_1_IP}}|g" \
            -e "s|dhakacart-k8s|{{CLUSTER_NAME}}|g" \
            -e "s|v1\.29|{{KUBERNETES_VERSION}}|g" \
            "$SCRIPT_DIR/master-1.sh" > "$TEMPLATES_DIR/master-1.sh.template"
        replace_template "$TEMPLATES_DIR/master-1.sh.template" "$GENERATED_DIR/master-1.sh"
    fi
fi

# Generate master-2.sh
if [ -f "$TEMPLATES_DIR/master-2.sh.template" ]; then
    replace_template "$TEMPLATES_DIR/master-2.sh.template" "$GENERATED_DIR/master-2.sh"
else
    echo -e "${YELLOW}⚠️  Template master-2.sh.template not found, creating from existing...${NC}"
    if [ -f "$SCRIPT_DIR/master-2.sh" ]; then
        sed -e "s|10\.0\.10\.[0-9]*|{{MASTER_1_IP}}|g" \
            -e "s|dhakacart-k8s|{{CLUSTER_NAME}}|g" \
            "$SCRIPT_DIR/master-2.sh" > "$TEMPLATES_DIR/master-2.sh.template"
        replace_template "$TEMPLATES_DIR/master-2.sh.template" "$GENERATED_DIR/master-2.sh"
    fi
fi

# Generate workers.sh
if [ -f "$TEMPLATES_DIR/workers.sh.template" ]; then
    replace_template "$TEMPLATES_DIR/workers.sh.template" "$GENERATED_DIR/workers.sh"
else
    echo -e "${YELLOW}⚠️  Template workers.sh.template not found, creating from existing...${NC}"
    if [ -f "$SCRIPT_DIR/workers.sh" ]; then
        sed -e "s|10\.0\.10\.[0-9]*|{{MASTER_1_IP}}|g" \
            -e "s|dhakacart-k8s|{{CLUSTER_NAME}}|g" \
            "$SCRIPT_DIR/workers.sh" > "$TEMPLATES_DIR/workers.sh.template"
        replace_template "$TEMPLATES_DIR/workers.sh.template" "$GENERATED_DIR/workers.sh"
    fi
fi

echo ""
echo -e "${GREEN}✅ All scripts generated successfully!${NC}"
echo "Generated files are in: $GENERATED_DIR"

