#!/bin/bash
# Performance Benchmark Script for DhakaCart
# Tests individual endpoint performance

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Performance Benchmarks${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

BASE_URL="${BASE_URL:-http://localhost:5000}"
ITERATIONS=100

echo "Target: $BASE_URL"
echo "Iterations per endpoint: $ITERATIONS"
echo ""

# Function to benchmark endpoint
benchmark_endpoint() {
    local name=$1
    local url=$2
    local method=${3:-GET}
    
    echo -e "${YELLOW}Benchmarking: $name${NC}"
    
    if [ "$method" = "GET" ]; then
        ab -n "$ITERATIONS" -c 10 -g "$name.tsv" "$url" > "$name.txt" 2>&1
    fi
    
    # Extract metrics
    TOTAL_TIME=$(grep "Time taken for tests" "$name.txt" | awk '{print $5}')
    REQ_PER_SEC=$(grep "Requests per second" "$name.txt" | awk '{print $4}')
    TIME_PER_REQ=$(grep "Time per request.*mean" "$name.txt" | head -1 | awk '{print $4}')
    FAILED=$(grep "Failed requests" "$name.txt" | awk '{print $3}')
    
    echo "  Total time: ${TOTAL_TIME}s"
    echo "  Requests/sec: $REQ_PER_SEC"
    echo "  Avg time/req: ${TIME_PER_REQ}ms"
    echo "  Failed: $FAILED"
    echo ""
}

# Check if Apache Bench is installed
if ! command -v ab &> /dev/null; then
    echo "Installing Apache Bench..."
    sudo apt-get install -y apache2-utils
fi

# Benchmark endpoints
benchmark_endpoint "health" "$BASE_URL/health"
benchmark_endpoint "products" "$BASE_URL/api/products"
benchmark_endpoint "categories" "$BASE_URL/api/categories"

echo -e "${GREEN}Benchmarks complete${NC}"
echo "Reports saved to current directory"

exit 0

