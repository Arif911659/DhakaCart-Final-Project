#!/bin/bash
# Load Testing Script for DhakaCart
# Runs K6 load tests with various configurations

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   DhakaCart Load Testing${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if K6 is installed
if ! command -v k6 &> /dev/null; then
    echo -e "${YELLOW}K6 not found. Installing...${NC}"
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo gpg -k
        sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
        echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
        sudo apt-get update
        sudo apt-get install k6
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install k6
    else
        echo -e "${RED}Please install K6 manually: https://k6.io/docs/get-started/installation/${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ K6 installed${NC}"
fi

# Get target URL
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Try to load infrastructure config if not set manually
if [ -z "$BASE_URL" ] && [ -f "$PROJECT_ROOT/scripts/load-infrastructure-config.sh" ]; then
    echo -e "${YELLOW}Loading infrastructure config...${NC}"
    source "$PROJECT_ROOT/scripts/load-infrastructure-config.sh" > /dev/null 2>&1
    if [ ! -z "$ALB_DNS" ]; then
        BASE_URL="http://$ALB_DNS"
        echo -e "${GREEN}✓ Auto-detected ALB: $BASE_URL${NC}"
    fi
fi

BASE_URL="${BASE_URL:-http://localhost:5000}"
echo -e "${YELLOW}Target URL: $BASE_URL${NC}"
echo ""

# Test options
echo -e "${YELLOW}Select test type:${NC}"
echo "1. Smoke Test (2 VUs, 30s) - Quick functionality check"
echo "2. Load Test (100 VUs, 10m) - Normal load"
echo "3. Stress Test (500 VUs, 15m) - High load"
echo "4. Spike Test (1000 VUs, 5m) - Sudden traffic spike"
echo "5. Endurance Test (50 VUs, 1h) - Long-running stability"
echo "6. Custom Test"
echo ""

read -p "Enter choice (1-6): " TEST_TYPE

case $TEST_TYPE in
    1)
        TEST_NAME="Smoke Test"
        K6_OPTIONS="--vus 2 --duration 30s"
        ;;
    2)
        TEST_NAME="Load Test"
        K6_OPTIONS="--vus 100 --duration 10m"
        ;;
    3)
        TEST_NAME="Stress Test"
        K6_OPTIONS="--vus 500 --duration 15m"
        ;;
    4)
        TEST_NAME="Spike Test"
        K6_OPTIONS="--vus 1000 --duration 5m"
        ;;
    5)
        TEST_NAME="Endurance Test"
        K6_OPTIONS="--vus 50 --duration 1h"
        ;;
    6)
        TEST_NAME="Custom Test"
        read -p "Enter number of virtual users: " VUS
        read -p "Enter duration (e.g., 10m, 1h): " DURATION
        K6_OPTIONS="--vus $VUS --duration $DURATION"
        ;;
    *)
        echo "Invalid option. Using Load Test."
        TEST_NAME="Load Test"
        K6_OPTIONS="--vus 100 --duration 10m"
        ;;
esac

# Report directory
REPORT_DIR="./reports/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$REPORT_DIR"

echo ""
echo -e "${GREEN}Starting $TEST_NAME...${NC}"
echo -e "${YELLOW}Reports will be saved to: $REPORT_DIR${NC}"
echo ""

# Run K6 test
k6 run \
    --out json="$REPORT_DIR/results.json" \
    --summary-export="$REPORT_DIR/summary.json" \
    -e BASE_URL="$BASE_URL" \
    $K6_OPTIONS \
    k6-load-test.js

# Generate HTML report (if K6 reporter is installed)
if command -v k6-reporter &> /dev/null; then
    k6-reporter "$REPORT_DIR/results.json" --output "$REPORT_DIR/report.html"
    echo -e "${GREEN}✓ HTML report generated: $REPORT_DIR/report.html${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Test Complete${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Results: $REPORT_DIR"
echo ""
echo "Key Metrics:"
k6 inspect --summary "$REPORT_DIR/summary.json" 2>/dev/null || echo "View full results in $REPORT_DIR/results.json"

exit 0

