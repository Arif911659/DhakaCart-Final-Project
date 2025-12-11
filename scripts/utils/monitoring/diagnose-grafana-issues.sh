#!/bin/bash

# ==========================================
# Diagnose Grafana Issues
# ==========================================
# 🇧🇩 এই স্ক্রিপ্ট Grafana লগ এবং পড স্ট্যাটাস চেক করে সমস্যা বের করে।
# 🇺🇸 This script checks Grafana logs and pod status to identify issues.
#
# Usage: ./diagnose-grafana-issues.sh

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
BASTION_IP="54.251.183.40"
MASTER1_IP="10.0.10.82"
SSH_KEY_PATH="$PROJECT_ROOT/terraform/aws-infra/dhakacart-k8s-key.pem"
REMOTE_USER="ubuntu"

echo -e "${BLUE}===========================================${NC}"
echo -e "${BLUE}Grafana Diagnostic Tool${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""

ssh -i "$SSH_KEY_PATH" "$REMOTE_USER@$BASTION_IP" "ssh -i ~/.ssh/dhakacart-k8s-key.pem -o StrictHostKeyChecking=no $REMOTE_USER@$MASTER1_IP" << 'EOF'
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}1. Checking Monitoring Pods...${NC}"
kubectl get pods -n monitoring
echo ""

echo -e "${BLUE}2. Checking Grafana Configuration...${NC}"
GRAFANA_POD=$(kubectl get pod -n monitoring -l app=grafana -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || echo "")
if [ -n "$GRAFANA_POD" ]; then
    echo "Grafana pod: $GRAFANA_POD"
    kubectl get deployment grafana -n monitoring -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="GF_SERVER_ROOT_URL")].value}' 2>/dev/null || echo "Not found"
    echo ""
    kubectl get deployment grafana -n monitoring -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="GF_SERVER_SERVE_FROM_SUB_PATH")].value}' 2>/dev/null || echo "Not found"
else
    echo -e "${RED}❌ Grafana pod not found!${NC}"
fi
echo ""

echo -e "${BLUE}3. Checking Prometheus Service...${NC}"
kubectl get svc prometheus-service -n monitoring
echo ""

echo -e "${BLUE}4. Testing Prometheus Connectivity from Grafana Pod...${NC}"
if [ -n "$GRAFANA_POD" ]; then
    kubectl exec -n monitoring $GRAFANA_POD -- wget -q -O- --timeout=5 http://prometheus-service.monitoring.svc.cluster.local:9090/prometheus/-/healthy 2>&1 | head -1 || echo -e "${RED}❌ Cannot connect to Prometheus${NC}"
else
    echo -e "${RED}❌ Grafana pod not found${NC}"
fi
echo ""

echo -e "${BLUE}5. Checking Prometheus Targets...${NC}"
PROMETHEUS_POD=$(kubectl get pod -n monitoring -l app=prometheus-server -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || echo "")
if [ -n "$PROMETHEUS_POD" ]; then
    echo "Prometheus pod: $PROMETHEUS_POD"
    echo ""
    echo "Active targets:"
    kubectl exec -n monitoring $PROMETHEUS_POD -- wget -q -O- http://localhost:9090/prometheus/api/v1/targets 2>/dev/null | grep -o '"health":"[^"]*","labels":[^}]*}' | head -3 || echo "Cannot fetch targets"
else
    echo -e "${RED}❌ Prometheus pod not found!${NC}"
fi
echo ""

echo -e "${BLUE}6. Checking Node Exporter Pods...${NC}"
NODE_EXPORTER_COUNT=$(kubectl get pods -n monitoring -l app=node-exporter --no-headers 2>/dev/null | wc -l || echo "0")
if [ "$NODE_EXPORTER_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✅ Node exporter pods: $NODE_EXPORTER_COUNT${NC}"
    kubectl get pods -n monitoring -l app=node-exporter --no-headers | head -3
else
    echo -e "${RED}❌ No node-exporter pods found!${NC}"
fi
echo ""

echo -e "${BLUE}7. Checking Pod Annotations (Prometheus Scraping)...${NC}"
echo "Backend pods with prometheus annotations:"
kubectl get pods -n dhakacart -l app=dhakacart-backend -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.metadata.annotations.prometheus\.io/scrape}{"\n"}{end}' 2>/dev/null || echo "No backend pods"
echo ""
echo "Frontend pods with prometheus annotations:"
kubectl get pods -n dhakacart -l app=dhakacart-frontend -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.metadata.annotations.prometheus\.io/scrape}{"\n"}{end}' 2>/dev/null || echo "No frontend pods"
echo ""

echo -e "${BLUE}8. Checking Prometheus RBAC...${NC}"
kubectl get serviceaccount prometheus -n monitoring 2>&1 | head -2 || echo -e "${RED}❌ Prometheus service account not found${NC}"
kubectl get clusterrolebinding | grep prometheus || echo "No cluster role binding found"
echo ""

echo -e "${BLUE}9. Checking Grafana Datasource ConfigMap...${NC}"
kubectl get configmap grafana-datasources -n monitoring -o yaml | grep -A 5 "prometheus.yaml:" | head -10 || echo "ConfigMap not found"
echo ""

echo -e "${BLUE}===========================================${NC}"
echo -e "${BLUE}Summary & Recommendations${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""
echo -e "${YELLOW}Common Issues:${NC}"
echo "1. If Prometheus cannot connect: Check service name and port"
echo "2. If no targets: Check node-exporter pods and pod annotations"
echo "3. If Grafana shows 'No data': Check Prometheus datasource URL"
echo "4. If dashboard import fails: Verify Prometheus is default datasource"
echo ""

EOF

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Diagnostic failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Diagnostic complete!${NC}"
echo ""

