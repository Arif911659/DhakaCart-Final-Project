#!/bin/bash

# ============================================
# Register Worker Nodes to ALB Target Groups
# ============================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}🔄 Registering Worker Nodes to ALB Target Groups...${NC}"
echo ""

# Get Terraform outputs
echo -e "${YELLOW}📊 Fetching Terraform outputs...${NC}"
FRONTEND_TG=$(terraform output -raw frontend_target_group_arn)
BACKEND_TG=$(terraform output -raw backend_target_group_arn)
WORKER_IPS=$(terraform output -json worker_private_ips | jq -r '.[]')

echo -e "${GREEN}✅ Frontend Target Group: ${FRONTEND_TG}${NC}"
echo -e "${GREEN}✅ Backend Target Group: ${BACKEND_TG}${NC}"
echo -e "${GREEN}✅ Worker IPs: ${NC}"
echo "$WORKER_IPS"
echo ""

# Get VPC ID to find instance IDs
VPC_ID=$(terraform output -raw vpc_id)

# Find Worker Instance IDs
echo -e "${YELLOW}🔍 Finding Worker Instance IDs...${NC}"
WORKER_INSTANCE_IDS=$(aws ec2 describe-instances \
  --filters "Name=vpc-id,Values=${VPC_ID}" \
            "Name=tag:Name,Values=*worker*" \
            "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].InstanceId' \
  --output text)

echo -e "${GREEN}✅ Worker Instance IDs: ${WORKER_INSTANCE_IDS}${NC}"
echo ""

# Register workers to Frontend Target Group (Port 30080)
echo -e "${YELLOW}📝 Registering workers to Frontend Target Group (NodePort 30080)...${NC}"
for INSTANCE_ID in $WORKER_INSTANCE_IDS; do
    aws elbv2 register-targets \
      --target-group-arn "${FRONTEND_TG}" \
      --targets Id=${INSTANCE_ID},Port=30080
    echo -e "${GREEN}✅ Registered ${INSTANCE_ID} to Frontend TG${NC}"
done
echo ""

# Register workers to Backend Target Group (Port 30081)
echo -e "${YELLOW}📝 Registering workers to Backend Target Group (NodePort 30081)...${NC}"
for INSTANCE_ID in $WORKER_INSTANCE_IDS; do
    aws elbv2 register-targets \
      --target-group-arn "${BACKEND_TG}" \
      --targets Id=${INSTANCE_ID},Port=30081
    echo -e "${GREEN}✅ Registered ${INSTANCE_ID} to Backend TG${NC}"
done
echo ""

# Wait for health checks
echo -e "${YELLOW}⏳ Waiting 30 seconds for health checks...${NC}"
sleep 30

# Check health status
echo -e "${YELLOW}🏥 Checking Frontend Target Health...${NC}"
aws elbv2 describe-target-health \
  --target-group-arn "${FRONTEND_TG}" \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
  --output table

echo ""
echo -e "${YELLOW}🏥 Checking Backend Target Health...${NC}"
aws elbv2 describe-target-health \
  --target-group-arn "${BACKEND_TG}" \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
  --output table

echo ""
echo -e "${GREEN}🎉 Registration Complete!${NC}"
echo -e "${GREEN}🌐 Access your application at:${NC}"
terraform output load_balancer_url
