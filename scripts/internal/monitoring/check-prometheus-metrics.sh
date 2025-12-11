#!/bin/bash

# ==========================================
# Check Prometheus Metrics
# ==========================================
# 🇧🇩 এই স্ক্রিপ্ট চেক করে Prometheus ঠিকমতো মেট্রিক্স পাচ্ছে কিনা।
# 🇺🇸 This script checks if Prometheus is scraping metrics correctly.
#
# Usage: ./check-prometheus-metrics.sh

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BASTION_IP="54.251.183.40"
MASTER1_IP="10.0.10.82"
SSH_KEY_PATH="$PROJECT_ROOT/terraform/simple-k8s/dhakacart-k8s-key.pem"
REMOTE_USER="ubuntu"

echo -e "${BLUE}===========================================${NC}"
echo -e "${BLUE}Prometheus Metrics Check${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""

ssh -i "$SSH_KEY_PATH" "$REMOTE_USER@$BASTION_IP" "ssh -i ~/.ssh/dhakacart-k8s-key.pem -o StrictHostKeyChecking=no $REMOTE_USER@$MASTER1_IP" << 'EOF'
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

PROM_POD=$(kubectl get pod -n monitoring -l app=prometheus-server -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || echo "")

if [ -z "$PROM_POD" ]; then
    echo -e "${RED}❌ Prometheus pod not found!${NC}"
    exit 1
fi

echo -e "${BLUE}1. Prometheus Health...${NC}"
kubectl exec -n monitoring $PROM_POD -- wget -q -O- http://localhost:9090/prometheus/-/healthy 2>&1 || echo "Health check failed"
echo ""

echo -e "${BLUE}2. Prometheus Targets Status...${NC}"
TARGETS=$(kubectl exec -n monitoring $PROM_POD -- wget -q -O- http://localhost:9090/prometheus/api/v1/targets 2>/dev/null || echo "")

if [ -n "$TARGETS" ]; then
    echo "$TARGETS" | grep -o '"health":"[^"]*","labels":{"[^}]*}' | while IFS= read -r line; do
        HEALTH=$(echo "$line" | grep -o '"health":"[^"]*"' | cut -d'"' -f4)
        JOB=$(echo "$line" | grep -o '"job":"[^"]*"' | cut -d'"' -f4)
        INSTANCE=$(echo "$line" | grep -o '"instance":"[^"]*"' | cut -d'"' -f4)
        if [ "$HEALTH" = "up" ]; then
            echo -e "${GREEN}✅ $JOB ($INSTANCE): $HEALTH${NC}"
        else
            echo -e "${RED}❌ $JOB ($INSTANCE): $HEALTH${NC}"
        fi
    done
else
    echo -e "${RED}❌ Cannot fetch targets${NC}"
fi
echo ""

echo -e "${BLUE}3. Available Metrics (sample)...${NC}"
kubectl exec -n monitoring $PROM_POD -- wget -q -O- http://localhost:9090/prometheus/api/v1/label/__name__/values 2>/dev/null | grep -o '"[^"]*"' | head -20 | sed 's/"//g' || echo "Cannot fetch metrics"
echo ""

echo -e "${BLUE}4. Node Exporter Metrics...${NC}"
kubectl exec -n monitoring $PROM_POD -- wget -q -O- 'http://localhost:9090/prometheus/api/v1/query?query=up{job="kubernetes-nodes"}' 2>/dev/null | grep -o '"value":\[[^]]*\]' | head -5 || echo "No node metrics found"
echo ""

echo -e "${BLUE}5. Testing Prometheus Query (up metric)...${NC}"
kubectl exec -n monitoring $PROM_POD -- wget -q -O- 'http://localhost:9090/prometheus/api/v1/query?query=up' 2>/dev/null | grep -o '"resultType":"[^"]*"' || echo "Query failed"
echo ""

echo -e "${BLUE}6. Node Exporter Pods...${NC}"
kubectl get pods -n monitoring -l app=node-exporter
echo ""

echo -e "${BLUE}7. Testing Node Exporter Directly...${NC}"
NODE_EXPORTER_POD=$(kubectl get pods -n monitoring -l app=node-exporter -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || echo "")
if [ -n "$NODE_EXPORTER_POD" ]; then
    echo "Node exporter pod: $NODE_EXPORTER_POD"
    kubectl exec -n monitoring $NODE_EXPORTER_POD -- wget -q -O- http://localhost:9100/metrics 2>/dev/null | head -5 || echo "Cannot fetch metrics from node-exporter"
else
    echo -e "${RED}❌ No node-exporter pods found${NC}"
fi
echo ""

echo -e "${BLUE}8. Grafana Datasource Configuration...${NC}"
kubectl get configmap grafana-datasources -n monitoring -o yaml | grep -A 10 "prometheus.yaml:" | head -15
echo ""

echo -e "${BLUE}===========================================${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}===========================================${NC}"
echo -e "${YELLOW}If targets show 'down', check:${NC}"
echo "  1. Node-exporter pods are running"
echo "  2. Prometheus RBAC permissions"
echo "  3. Network connectivity"
echo ""
echo -e "${YELLOW}If no metrics, check:${NC}"
echo "  1. Prometheus scrape config"
echo "  2. Service discovery working"
echo "  3. Target endpoints accessible"
echo ""

EOF

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Check failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Check complete!${NC}"
echo ""

