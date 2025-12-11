#!/bin/bash

# ==========================================
# Fix Grafana ALB Access
# ==========================================
# 🇧🇩 এই স্ক্রিপ্ট Grafana কে লোড ব্যালেন্সারের মাধ্যমে এক্সেস করার ব্যবস্থা করে।
# 🇺🇸 This script configures Grafana to be accessible via the Load Balancer.
#
# Usage: ./setup-grafana-alb.sh
# This script creates a target group and listener rule for Grafana

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_header() {
    echo ""
    print_message "$BLUE" "==========================================="
    print_message "$BLUE" "  $1"
    print_message "$BLUE" "==========================================="
    echo ""
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform/simple-k8s"

print_header "Fix Grafana ALB Access"

# Get Terraform outputs
print_message "$CYAN" "📊 Getting Terraform outputs..."
cd "$TERRAFORM_DIR"

ALB_ARN=$(terraform output -json | jq -r '.load_balancer_arn.value // empty')
if [ -z "$ALB_ARN" ]; then
    # Fallback: get ALB ARN by DNS name
    ALB_DNS=$(terraform output -json | jq -r '.load_balancer_dns.value')
    ALB_ARN=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?DNSName=='$ALB_DNS'].LoadBalancerArn" --output text)
fi

VPC_ID=$(terraform output -json | jq -r '.vpc_id.value')
WORKER_IPS=($(terraform output -json | jq -r '.worker_private_ips.value[]'))

print_message "$GREEN" "✅ ALB ARN: $ALB_ARN"
print_message "$GREEN" "✅ VPC ID: $VPC_ID"
print_message "$GREEN" "✅ Worker IPs: ${WORKER_IPS[@]}"

# Get HTTP listener ARN
print_message "$CYAN" "🔍 Finding HTTP listener..."
LISTENER_ARN=$(aws elbv2 describe-listeners \
    --load-balancer-arn "$ALB_ARN" \
    --query "Listeners[?Port==\`80\`].ListenerArn" \
    --output text)

if [ -z "$LISTENER_ARN" ]; then
    print_message "$RED" "❌ HTTP listener not found on port 80"
    exit 1
fi

print_message "$GREEN" "✅ Listener ARN: $LISTENER_ARN"

# Check if Grafana target group already exists
print_message "$CYAN" "🔍 Checking for existing Grafana target group..."
EXISTING_TG=$(aws elbv2 describe-target-groups \
    --query "TargetGroups[?TargetGroupName=='dhakacart-k8s-grafana-tg'].TargetGroupArn" \
    --output text)

if [ -n "$EXISTING_TG" ]; then
    print_message "$YELLOW" "⚠️  Grafana target group already exists: $EXISTING_TG"
    GRAFANA_TG_ARN="$EXISTING_TG"
else
    # Create Grafana target group
    print_message "$CYAN" "📝 Creating Grafana target group..."
    GRAFANA_TG_ARN=$(aws elbv2 create-target-group \
        --name dhakacart-k8s-grafana-tg \
        --protocol HTTP \
        --port 30091 \
        --vpc-id "$VPC_ID" \
        --target-type instance \
        --health-check-enabled \
        --health-check-protocol HTTP \
        --health-check-path /grafana/api/health \
        --health-check-interval-seconds 30 \
        --health-check-timeout-seconds 5 \
        --healthy-threshold-count 2 \
        --unhealthy-threshold-count 3 \
        --matcher HttpCode=200 \
        --query 'TargetGroups[0].TargetGroupArn' \
        --output text)
    
    print_message "$GREEN" "✅ Created Grafana target group: $GRAFANA_TG_ARN"
fi

# Get worker instance IDs
print_message "$CYAN" "🔍 Finding worker instance IDs..."
WORKER_INSTANCE_IDS=()
for ip in "${WORKER_IPS[@]}"; do
    instance_id=$(aws ec2 describe-instances \
        --filters "Name=private-ip-address,Values=$ip" "Name=instance-state-name,Values=running" \
        --query "Reservations[0].Instances[0].InstanceId" \
        --output text)
    
    if [ -n "$instance_id" ] && [ "$instance_id" != "None" ]; then
        WORKER_INSTANCE_IDS+=("$instance_id")
        print_message "$GREEN" "  ✓ Found instance: $instance_id ($ip)"
    fi
done

# Register workers to Grafana target group
print_message "$CYAN" "📝 Registering workers to Grafana target group..."
for instance_id in "${WORKER_INSTANCE_IDS[@]}"; do
    aws elbv2 register-targets \
        --target-group-arn "$GRAFANA_TG_ARN" \
        --targets Id="$instance_id",Port=30091
    print_message "$GREEN" "  ✓ Registered $instance_id"
done

# Check if listener rule already exists for /grafana/*
print_message "$CYAN" "🔍 Checking for existing Grafana listener rule..."
EXISTING_RULE=$(aws elbv2 describe-rules \
    --listener-arn "$LISTENER_ARN" \
    --query "Rules[?contains(to_string(Conditions), 'grafana')].RuleArn" \
    --output text | head -1)

if [ -n "$EXISTING_RULE" ]; then
    print_message "$YELLOW" "⚠️  Grafana listener rule already exists: $EXISTING_RULE"
    print_message "$CYAN" "🗑️  Deleting old rule..."
    aws elbv2 delete-rule --rule-arn "$EXISTING_RULE"
    print_message "$GREEN" "✅ Deleted old rule"
fi

# Get existing rules to determine priority
print_message "$CYAN" "🔍 Determining rule priority..."
EXISTING_PRIORITIES=$(aws elbv2 describe-rules \
    --listener-arn "$LISTENER_ARN" \
    --query "Rules[?Priority!='default'].Priority" \
    --output text)

# Find next available priority
PRIORITY=10
for p in $EXISTING_PRIORITIES; do
    if [ "$p" -ge "$PRIORITY" ]; then
        PRIORITY=$((p + 1))
    fi
done

print_message "$CYAN" "📝 Creating Grafana listener rule with priority $PRIORITY..."
aws elbv2 create-rule \
    --listener-arn "$LISTENER_ARN" \
    --priority "$PRIORITY" \
    --conditions Field=path-pattern,Values='/grafana/*' \
    --actions Type=forward,TargetGroupArn="$GRAFANA_TG_ARN"

print_message "$GREEN" "✅ Created Grafana listener rule"

# Wait for health checks
print_message "$CYAN" "⏳ Waiting 30 seconds for health checks..."
sleep 30

# Check target health
print_message "$CYAN" "🏥 Checking Grafana target health..."
aws elbv2 describe-target-health \
    --target-group-arn "$GRAFANA_TG_ARN" \
    --query "TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]" \
    --output table

print_header "Grafana ALB Setup Complete!"

ALB_DNS=$(terraform output -json | jq -r '.load_balancer_dns.value')
print_message "$GREEN" "🎉 Grafana is now accessible at:"
print_message "$YELLOW" "   http://$ALB_DNS/grafana/"
print_message "$YELLOW" "   Username: admin"
print_message "$YELLOW" "   Password: dhakacart123"
echo ""
