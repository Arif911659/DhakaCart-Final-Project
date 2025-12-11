#!/bin/bash
set -e

# register-workers-to-alb.sh
# Registers all worker nodes to the ALB Target Groups (Frontend & Backend)
# Uses Terraform outputs to find resources and AWS CLI to safe-guard registration.

echo "🔍 Fetching configuration from Terraform..."

# Check if terraform is initialized
if [ ! -d ".terraform" ]; then
    echo "❌ Terraform not initialized. Please run 'terraform init' first."
    exit 1
fi

# Get Outputs
VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")
FRONTEND_ARN=$(terraform output -raw frontend_target_group_arn 2>/dev/null || echo "")
BACKEND_ARN=$(terraform output -raw backend_target_group_arn 2>/dev/null || echo "")

if [ -z "$VPC_ID" ]; then
    echo "❌ Error: Could not get VPC ID from terraform output."
    echo "   Make sure you have applied the terraform configuration."
    exit 1
fi

echo "✅ Configuration found:"
echo "   - VPC ID:      $VPC_ID"
echo "   - Frontend TG: $FRONTEND_ARN"
echo "   - Backend TG:  $BACKEND_ARN"

echo ""
echo "🔍 Finding running worker instances..."

# Find instances in the VPC with tag Role=worker
# match instances that are running and have the Role=worker tag
WORKER_IDS=$(aws ec2 describe-instances \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Role,Values=worker" "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)

if [ -z "$WORKER_IDS" ]; then
    echo "❌ Error: No running worker instances found in VPC $VPC_ID with tag Role=worker"
    exit 1
fi

# Format with newlines for display
WORKER_LIST_DISPLAY=$(echo $WORKER_IDS | tr '\t' '\n' | sed 's/^/   - /')
echo "✅ Found workers:"
echo "$WORKER_LIST_DISPLAY"

echo ""

# Function to register targets
register_targets() {
    local arn=$1
    local port=$2
    local name=$3
    
    if [ -z "$arn" ]; then
        echo "⚠️  Skipping $name regsitration (Target Group ARN not found)"
        return
    fi

    echo "🔄 Registering workers to $name Target Group (Port $port)..."
    
    # Construct targets argument for AWS CLI
    # Format: Id=i-xxxx,Port=yyyy
    TARGET_ARGS=""
    for id in $WORKER_IDS; do
        TARGET_ARGS="$TARGET_ARGS Id=$id,Port=$port"
    done
    
    # Register
    aws elbv2 register-targets --target-group-arn "$arn" --targets $TARGET_ARGS
    
    echo "✅ Successfully registered workers to $name"
}

# Run registrations
register_targets "$FRONTEND_ARN" "30080" "Frontend"
register_targets "$BACKEND_ARN" "30081" "Backend"

echo ""
echo "============================================"
echo "🎉 ALB Registration Complete!"
echo "============================================"
