#!/bin/bash
# Container Image Security Scanning with Trivy
# Scans Docker images for vulnerabilities

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   DhakaCart Security Scan (Trivy)${NC}"
echo -e "${BLUE}========================================${NC}"
echo "Started at: $(date)"
echo ""

# Check if Trivy is installed
if ! command -v trivy &> /dev/null; then
    echo -e "${YELLOW}Trivy not found. Installing...${NC}"
    
    # Install Trivy
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
        echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
        sudo apt-get update
        sudo apt-get install -y trivy
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install trivy
    else
        echo -e "${RED}Please install Trivy manually: https://aquasecurity.github.io/trivy/${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Trivy installed${NC}"
fi

# Update Trivy database
echo -e "${YELLOW}Updating vulnerability database...${NC}"
trivy image --download-db-only
echo -e "${GREEN}✓ Database updated${NC}"
echo ""

# Images to scan
IMAGES=(
    "arifhossaincse22/dhakacart-backend:latest"
    "arifhossaincse22/dhakacart-frontend:latest"
    "postgres:15-alpine"
    "redis:7-alpine"
)

# Scan report directory
REPORT_DIR="/tmp/trivy-reports-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$REPORT_DIR"

# Track critical vulnerabilities
TOTAL_CRITICAL=0
TOTAL_HIGH=0
TOTAL_MEDIUM=0

# Scan each image
for IMAGE in "${IMAGES[@]}"; do
    echo -e "${YELLOW}Scanning: $IMAGE${NC}"
    
    REPORT_FILE="$REPORT_DIR/$(echo $IMAGE | tr '/:' '_').txt"
    JSON_FILE="$REPORT_DIR/$(echo $IMAGE | tr '/:' '_').json"
    
    # Scan image (exit code 0 even if vulnerabilities found)
    trivy image \
        --severity CRITICAL,HIGH,MEDIUM \
        --format table \
        --output "$REPORT_FILE" \
        "$IMAGE" || true
    
    # Also generate JSON report
    trivy image \
        --severity CRITICAL,HIGH,MEDIUM \
        --format json \
        --output "$JSON_FILE" \
        "$IMAGE" || true
    
    # Count vulnerabilities
    CRITICAL=$(grep -c "CRITICAL" "$REPORT_FILE" || echo "0")
    HIGH=$(grep -c "HIGH" "$REPORT_FILE" || echo "0")
    MEDIUM=$(grep -c "MEDIUM" "$REPORT_FILE" || echo "0")
    
    TOTAL_CRITICAL=$((TOTAL_CRITICAL + CRITICAL))
    TOTAL_HIGH=$((TOTAL_HIGH + HIGH))
    TOTAL_MEDIUM=$((TOTAL_MEDIUM + MEDIUM))
    
    # Display summary
    if [ "$CRITICAL" -gt 0 ]; then
        echo -e "  ${RED}CRITICAL: $CRITICAL${NC}"
    else
        echo -e "  ${GREEN}CRITICAL: 0${NC}"
    fi
    
    if [ "$HIGH" -gt 0 ]; then
        echo -e "  ${YELLOW}HIGH: $HIGH${NC}"
    else
        echo -e "  ${GREEN}HIGH: 0${NC}"
    fi
    
    echo -e "  MEDIUM: $MEDIUM"
    echo ""
done

# Generate summary report
SUMMARY_FILE="$REPORT_DIR/SUMMARY.txt"
cat > "$SUMMARY_FILE" <<EOF
DhakaCart Security Scan Summary
================================
Scan Date: $(date)
Images Scanned: ${#IMAGES[@]}

Vulnerability Summary:
  CRITICAL: $TOTAL_CRITICAL
  HIGH: $TOTAL_HIGH
  MEDIUM: $TOTAL_MEDIUM

Individual Reports:
EOF

ls -1 "$REPORT_DIR"/*.txt | grep -v "SUMMARY" >> "$SUMMARY_FILE"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Scan Complete${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Total Vulnerabilities Found:"
if [ "$TOTAL_CRITICAL" -gt 0 ]; then
    echo -e "  ${RED}CRITICAL: $TOTAL_CRITICAL${NC}"
else
    echo -e "  ${GREEN}CRITICAL: 0${NC}"
fi

if [ "$TOTAL_HIGH" -gt 0 ]; then
    echo -e "  ${YELLOW}HIGH: $TOTAL_HIGH${NC}"
else
    echo -e "  ${GREEN}HIGH: 0${NC}"
fi
echo -e "  MEDIUM: $TOTAL_MEDIUM"
echo ""
echo "Reports saved to: $REPORT_DIR"
echo "Summary: $SUMMARY_FILE"
echo ""

# Recommendations
if [ "$TOTAL_CRITICAL" -gt 0 ] || [ "$TOTAL_HIGH" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Recommendations:${NC}"
    echo "1. Review detailed reports in $REPORT_DIR"
    echo "2. Update vulnerable packages"
    echo "3. Rebuild and redeploy images"
    echo "4. Consider using distroless or minimal base images"
    echo ""
fi

# Exit with error if critical vulnerabilities found
if [ "$TOTAL_CRITICAL" -gt 0 ]; then
    echo -e "${RED}❌ CRITICAL vulnerabilities found! Please address immediately.${NC}"
    exit 1
elif [ "$TOTAL_HIGH" -gt 5 ]; then
    echo -e "${YELLOW}⚠️  Multiple HIGH vulnerabilities found. Please review.${NC}"
    exit 1
else
    echo -e "${GREEN}✓ Security scan completed. No critical issues.${NC}"
    exit 0
fi

