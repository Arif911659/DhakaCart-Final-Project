#!/bin/bash

# ==============================================================================
# DhakaCart Production Deployment Script
# ==============================================================================
# 🇧🇩 এই স্ক্রিপ্ট মাস্টার নোডের ভেতর থেকে সব কুবারনেটিস ফাইল অ্যাপ্লাই করে।
# 🇺🇸 This script runs inside Master node to apply all K8s manifests.
#
# It handles:
# 1. Applying base resources (Namespace, Secrets, Volumes)
# 2. Applying ConfigMaps
# 3. auto-updating the ConfigMap with the correct ALB DNS
# 4. Applying Deployments and Services
# 5. Applying Ingress
# 6. Restarting deployments to ensure new config is picked up
# ==============================================================================

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}🚀 Starting DhakaCart Deployment...${NC}"
echo ""

# 1. Base Resources
# 🇧🇩 প্রথমে নেমস্পেস, সিক্রেট এবং ভলিউম তৈরি করা হয়
# 🇺🇸 Step 1: Create Namespace, Secrets, and Persistent Volumes
echo -e "${YELLOW}📦 Applying Base Resources...${NC}"
kubectl apply -f "$SCRIPT_DIR/namespace.yaml"
kubectl apply -f "$SCRIPT_DIR/secrets/"
kubectl apply -f "$SCRIPT_DIR/volumes/"
echo -e "${GREEN}✅ Base resources applied.${NC}"
echo ""

# 2. ConfigMaps
echo -e "${YELLOW}📝 Applying ConfigMaps...${NC}"
kubectl apply -f "$SCRIPT_DIR/configmaps/"
echo -e "${GREEN}✅ Base ConfigMaps applied.${NC}"
echo ""

# 3. Update ConfigMap with ALB DNS
# 3. Update ConfigMap with ALB DNS
# This step is skipped on remote because Terraform is not available.
# Ensure you ran ./update-configmap-with-alb-dns.sh LOCALLY before syncing.
echo -e "${GREEN}✅ Assuming app-config.yaml was updated locally before sync.${NC}"
echo ""

# 4. Deployments and Services
# 🇧🇩 অ্যাপ্লিকেশনের পড এবং সার্ভিস চালু করা (Frontend, Backend, DB, Redis)
# 🇺🇸 Step 4: Deploy application Pods and Services
echo -e "${YELLOW}🚀 Applying Deployments and Services...${NC}"
kubectl apply -f "$SCRIPT_DIR/deployments/"
kubectl apply -f "$SCRIPT_DIR/services/"
echo -e "${GREEN}✅ Deployments and Services applied.${NC}"
echo ""

# 4.1. Horizontal Pod Autoscaler (HPA)
echo -e "${YELLOW}📈 Applying HPA...${NC}"
if [ -f "$SCRIPT_DIR/hpa.yaml" ]; then
    kubectl apply -f "$SCRIPT_DIR/hpa.yaml"
    echo -e "${GREEN}✅ HPA applied.${NC}"
else
    echo -e "${YELLOW}ℹ️  hpa.yaml not found, skipping...${NC}"
fi
echo ""

# 4.5. Monitoring & Logging Stack
echo -e "${YELLOW}📊 Applying Monitoring & Logging Stack...${NC}"
# Namespace
kubectl apply -f "$SCRIPT_DIR/monitoring/namespace.yaml"
# Prometheus
kubectl apply -f "$SCRIPT_DIR/monitoring/prometheus/rbac.yaml"
kubectl apply -f "$SCRIPT_DIR/monitoring/prometheus/configmap.yaml"
kubectl apply -f "$SCRIPT_DIR/monitoring/prometheus/deployment.yaml"
kubectl apply -f "$SCRIPT_DIR/monitoring/prometheus/service.yaml"
# Node Exporter
kubectl apply -f "$SCRIPT_DIR/monitoring/node-exporter/daemonset.yaml"
# Grafana
kubectl apply -f "$SCRIPT_DIR/monitoring/grafana/datasource-config.yaml"
kubectl apply -f "$SCRIPT_DIR/monitoring/grafana/deployment.yaml"
kubectl apply -f "$SCRIPT_DIR/monitoring/grafana/service.yaml"
# Loki
kubectl apply -f "$SCRIPT_DIR/monitoring/loki/configmap.yaml"
kubectl apply -f "$SCRIPT_DIR/monitoring/loki/deployment.yaml"
kubectl apply -f "$SCRIPT_DIR/monitoring/loki/service.yaml"
# Promtail
kubectl apply -f "$SCRIPT_DIR/monitoring/promtail/rbac.yaml"
kubectl apply -f "$SCRIPT_DIR/monitoring/promtail/configmap.yaml"
kubectl apply -f "$SCRIPT_DIR/monitoring/promtail/daemonset.yaml"
# Alertmanager
kubectl apply -f "$SCRIPT_DIR/monitoring/prometheus/alert-rules.yaml"
kubectl apply -f "$SCRIPT_DIR/monitoring/alertmanager/configmap.yaml"
kubectl apply -f "$SCRIPT_DIR/monitoring/alertmanager/deployment.yaml"
kubectl apply -f "$SCRIPT_DIR/monitoring/alertmanager/service.yaml"

echo -e "${GREEN}✅ Monitoring & Logging stack applied.${NC}"
echo ""

# 5. Ingress
echo -e "${YELLOW}🌐 Applying Ingress...${NC}"
if [ -f "$SCRIPT_DIR/ingress/ingress-alb.yaml" ]; then
    kubectl apply -f "$SCRIPT_DIR/ingress/ingress-alb.yaml"
    echo -e "${GREEN}✅ ALB Ingress applied.${NC}"
else
    echo -e "${YELLOW}ℹ️  ingress-alb.yaml not found, applying default ingress...${NC}"
    kubectl apply -f "$SCRIPT_DIR/ingress/"
fi
echo ""

# 5.5. Security Policies
echo -e "${YELLOW}🔒 Applying Security Policies...${NC}"
if [ -d "$SCRIPT_DIR/security/network-policies" ]; then
    kubectl apply -f "$SCRIPT_DIR/security/network-policies/"
    echo -e "${GREEN}✅ Security Policies applied.${NC}"
else
    echo -e "${YELLOW}ℹ️  Security policies not found at $SCRIPT_DIR/security/network-policies${NC}"
fi
echo ""



# 6. Database Check & Seeding
echo -e "${YELLOW}💾 Checking Database Status...${NC}"

# Function to check database
check_and_seed_db() {
    echo "Waiting for database pod to be ready..."
    kubectl wait --for=condition=ready pod -l app=dhakacart-db -n dhakacart --timeout=120s
    
    # Get Pod Name
    DB_POD=$(kubectl get pod -l app=dhakacart-db -n dhakacart -o jsonpath="{.items[0].metadata.name}")

    # Check/Create Database
    echo "Checking if database 'dhakacart' exists..."
    DB_EXISTS=$(kubectl exec -i -n dhakacart "$DB_POD" -- psql -U dhakacart -d postgres -t -c "SELECT 1 FROM pg_database WHERE datname='dhakacart';" 2>/dev/null || echo "0")
    
    if [ "$(echo "$DB_EXISTS" | tr -d '[:space:]')" != "1" ]; then
        echo -e "${YELLOW}⚡ Database 'dhakacart' not found. Creating...${NC}"
        kubectl exec -i -n dhakacart "$DB_POD" -- psql -U dhakacart -d postgres -c "CREATE DATABASE dhakacart;"
        echo -e "${GREEN}✅ Database 'dhakacart' created.${NC}"
    else
        echo -e "${GREEN}✅ Database 'dhakacart' exists.${NC}"
    fi
    
    # Check if products table exists
    ROW_COUNT=$(kubectl exec -i -n dhakacart "$DB_POD" -- psql -U dhakacart -d dhakacart -t -c "SELECT count(*) FROM information_schema.tables WHERE table_name = 'products';" 2>/dev/null || echo "0")
    
    if [ "$(echo "$ROW_COUNT" | tr -d '[:space:]')" = "1" ]; then
         echo -e "${GREEN}✅ Schema already initialized (products table found). Skipping seed.${NC}"
    else
         echo -e "${YELLOW}⚡ Schema missing/empty. Seeding data...${NC}"
         kubectl exec -i -n dhakacart "$DB_POD" -- psql -U dhakacart -d dhakacart < "$SCRIPT_DIR/../database/init.sql"
         echo -e "${GREEN}✅ Database seeded successfully!${NC}"
    fi
}
# Run check in background or foreground? Foreground is safer for first deploy.
check_and_seed_db
echo ""

# 7. Restart for Consistency
# 🇧🇩 কনফিগারেশন আপডেট নিশ্চিত করতে ফ্রন্টএন্ড ও ব্যাকএন্ড রিস্টার্ট করা হয়
# 🇺🇸 Step 7: Restart pods to enforce latest config changes
echo -e "${YELLOW}🔄 Restarting Frontend and Backend to ensure config pickup...${NC}"
kubectl rollout restart deployment/dhakacart-frontend -n dhakacart
kubectl rollout restart deployment/dhakacart-backend -n dhakacart
echo -e "${GREEN}✅ Rollout restart triggered.${NC}"
echo ""

echo -e "${GREEN}🎉 Deployment Complete!${NC}"
echo -e "Check status with: ${YELLOW}kubectl get all -n dhakacart${NC}"
