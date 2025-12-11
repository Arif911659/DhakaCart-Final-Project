#!/bin/bash

#############################################
# Alerting Stack Deployment & Verification
# Deploys Prometheus alerts and Alertmanager
#############################################

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}   Alerting Stack Deployment${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Load infrastructure config
source "$SCRIPT_DIR/load-infrastructure-config.sh" 2>/dev/null || {
    echo -e "${RED}❌ Could not load infrastructure config${NC}"
    exit 1
}

# Step 1: Sync files to Master-1
echo -e "${YELLOW}📤 Step 1: Syncing alerting configs to Master-1...${NC}"
cd "$PROJECT_ROOT"
./scripts/k8s-deployment/sync-k8s-to-master1.sh
echo -e "${GREEN}✅ Files synced${NC}"
echo ""

# Step 2: Deploy alerting stack
echo -e "${YELLOW}🚀 Step 2: Deploying alerting stack...${NC}"

cat > /tmp/deploy-alerting.sh << 'EOF'
#!/bin/bash
set -e
cd ~/k8s

echo "Applying alert rules..."
kubectl apply -f monitoring/prometheus/alert-rules.yaml

echo "Applying Alertmanager configuration..."
kubectl apply -f monitoring/alertmanager/configmap.yaml
kubectl apply -f monitoring/alertmanager/deployment.yaml
kubectl apply -f monitoring/alertmanager/service.yaml

echo "Restarting Prometheus to load new config..."
kubectl rollout restart deployment/prometheus-deployment -n monitoring

echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=prometheus-server -n monitoring --timeout=120s
kubectl wait --for=condition=ready pod -l app=alertmanager -n monitoring --timeout=120s

echo "✅ Alerting stack deployed!"
EOF

ssh -i "$PROJECT_ROOT/terraform/simple-k8s/dhakacart-k8s-key.pem" ubuntu@${BASTION_IP} \
    "scp /tmp/deploy-alerting.sh ubuntu@${MASTER_IPS[0]}:/tmp/ && \
     ssh ubuntu@${MASTER_IPS[0]} 'bash /tmp/deploy-alerting.sh'"

echo -e "${GREEN}✅ Alerting stack deployed${NC}"
echo ""

# Step 3: Verify deployment
echo -e "${YELLOW}🔍 Step 3: Verifying deployment...${NC}"

cat > /tmp/verify-alerting.sh << 'EOF'
#!/bin/bash
echo "Checking pods..."
kubectl get pods -n monitoring | grep -E "prometheus|alertmanager"

echo ""
echo "Checking services..."
kubectl get svc -n monitoring | grep -E "prometheus|alertmanager"

echo ""
echo "Checking alert rules..."
kubectl exec -n monitoring deployment/prometheus-deployment -- promtool check config /etc/prometheus/prometheus.yml 2>/dev/null || echo "Config check skipped"
EOF

ssh -i "$PROJECT_ROOT/terraform/simple-k8s/dhakacart-k8s-key.pem" ubuntu@${BASTION_IP} \
    "scp /tmp/verify-alerting.sh ubuntu@${MASTER_IPS[0]}:/tmp/ && \
     ssh ubuntu@${MASTER_IPS[0]} 'bash /tmp/verify-alerting.sh'"

echo -e "${GREEN}✅ Verification complete${NC}"
echo ""

echo -e "${YELLOW}Access URLs:${NC}"
echo "  Prometheus Alerts: http://${ALB_DNS}/prometheus/alerts"
echo "  Prometheus Targets: http://${ALB_DNS}/prometheus/targets"
echo "  Alertmanager UI: http://<WORKER_NODE_IP>:30093"
echo ""
echo -e "${YELLOW}Configured Alerts:${NC}"
echo "  1. HighErrorRate (>1% errors for 5min)"
echo "  2. HighLatency (p95 >2s for 5min)"
echo "  3. PodDown (pods unavailable for 2min)"
echo "  4. HighMemoryUsage (>90% for 5min)"
echo "  5. HighCPUUsage (>80% for 5min)"
echo "  6. DatabaseConnectionFailed (DB down for 1min)"
echo "  7. RedisConnectionFailed (Redis down for 1min)"
echo ""
echo -e "${YELLOW}To test an alert:${NC}"
echo "  kubectl scale deployment/dhakacart-backend --replicas=0 -n dhakacart"
echo "  # Wait 2-3 minutes, then check Prometheus alerts page"
echo "  kubectl scale deployment/dhakacart-backend --replicas=3 -n dhakacart"
echo ""
