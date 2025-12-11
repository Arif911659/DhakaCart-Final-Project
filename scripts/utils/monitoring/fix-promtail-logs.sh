#!/bin/bash

# ==========================================
# Fix Promtail Log Collection
# ==========================================
# 🇧🇩 এই স্ক্রিপ্ট Promtail কনফিগারেশন ঠিক করে যাতে লগগুলো Loki তে যায়।
# 🇺🇸 This script fixes Promtail configuration to ensure logs are sent to Loki.
#
# Usage: ./fix-promtail-logs.sh
# This script updates Promtail configuration to correctly collect logs

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
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform/aws-infra"
BASTION_IP="54.251.183.40"
MASTER1_IP="10.0.10.82"
SSH_KEY_PATH="$TERRAFORM_DIR/dhakacart-k8s-key.pem"
REMOTE_USER="ubuntu"

print_header "Fix Promtail Log Collection"

print_message "$CYAN" "📝 Creating updated Promtail configuration..."

# Create updated Promtail config
cat > /tmp/promtail-config-fixed.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: promtail-config
  namespace: monitoring
data:
  promtail.yaml: |
    server:
      http_listen_port: 9080
      grpc_listen_port: 0

    positions:
      filename: /run/promtail/positions.yaml

    clients:
      - url: http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push

    scrape_configs:
      - job_name: kubernetes-pods
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_node_name]
            target_label: __host__
          - action: labelmap
            regex: __meta_kubernetes_pod_label_(.+)
          - action: replace
            source_labels: [__meta_kubernetes_namespace]
            target_label: namespace
          - action: replace
            source_labels: [__meta_kubernetes_pod_name]
            target_label: pod
          - action: replace
            source_labels: [__meta_kubernetes_pod_container_name]
            target_label: container
          - action: replace
            replacement: /var/log/pods/*$1/*/*.log
            separator: /
            source_labels: [__meta_kubernetes_pod_uid]
            target_label: __path__
EOF

print_message "$GREEN" "✅ Configuration file created"

print_message "$CYAN" "📤 Uploading configuration to Master-1..."

# Copy config to bastion
scp -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no /tmp/promtail-config-fixed.yaml "$REMOTE_USER@$BASTION_IP:/tmp/"

# Copy from bastion to master1 and apply
ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$REMOTE_USER@$BASTION_IP" << EOF
    scp -i ~/.ssh/dhakacart-k8s-key.pem -o StrictHostKeyChecking=no /tmp/promtail-config-fixed.yaml $REMOTE_USER@$MASTER1_IP:/tmp/
    
    ssh -i ~/.ssh/dhakacart-k8s-key.pem -o StrictHostKeyChecking=no $REMOTE_USER@$MASTER1_IP << 'INNER_EOF'
        echo "Applying updated Promtail configuration..."
        kubectl apply -f /tmp/promtail-config-fixed.yaml
        
        echo "Restarting Promtail daemonset..."
        kubectl rollout restart daemonset/promtail -n monitoring
        
        echo "Waiting for Promtail pods to be ready..."
        kubectl rollout status daemonset/promtail -n monitoring --timeout=60s
        
        echo "Checking Promtail pods..."
        kubectl get pods -n monitoring | grep promtail
        
        echo "Waiting 10 seconds for log collection to start..."
        sleep 10
        
        echo "Checking positions file..."
        kubectl exec -n monitoring daemonset/promtail -- cat /run/promtail/positions.yaml | head -20
INNER_EOF
EOF

print_message "$GREEN" "✅ Promtail configuration updated and restarted"

print_header "Promtail Fix Complete!"

print_message "$YELLOW" "📊 Please wait 1-2 minutes for logs to appear in Grafana"
print_message "$YELLOW" "🔍 Then try querying in Loki Explore with: {namespace=\"dhakacart\"}"
echo ""
