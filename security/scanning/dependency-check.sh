#!/bin/bash
# Dependency Vulnerability Scanning
# Scans npm dependencies for known vulnerabilities

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Dependency Security Audit${NC}"
echo -e "${BLUE}========================================${NC}"
echo "Started at: $(date)"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPORT_DIR="/tmp/dependency-audit-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$REPORT_DIR"

# Function to audit npm dependencies
audit_npm() {
    local dir=$1
    local name=$2
    
    echo -e "${YELLOW}Auditing: $name${NC}"
    echo "  Directory: $dir"
    
    if [ ! -f "$dir/package.json" ]; then
        echo -e "  ${RED}No package.json found${NC}"
        return 1
    fi
    
    cd "$dir"
    
    # Run npm audit
    # Capture JSON output only to json file, stderr to /dev/null
    npm audit --json > "$REPORT_DIR/${name}-audit.json" || true
    # Capture human readable output
    npm audit > "$REPORT_DIR/${name}-audit.txt" 2>&1 || true
    
    # Parse results
    CRITICAL=$(jq '.metadata.vulnerabilities.critical // 0' "$REPORT_DIR/${name}-audit.json")
    HIGH=$(jq '.metadata.vulnerabilities.high // 0' "$REPORT_DIR/${name}-audit.json")
    MODERATE=$(jq '.metadata.vulnerabilities.moderate // 0' "$REPORT_DIR/${name}-audit.json")
    LOW=$(jq '.metadata.vulnerabilities.low // 0' "$REPORT_DIR/${name}-audit.json")
    
    # Display results
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
    
    echo -e "  MODERATE: $MODERATE"
    echo -e "  LOW: $LOW"
    echo ""
    
    # Return to project root
    cd "$PROJECT_ROOT"
    
    return 0
}

# Audit Backend
if [ -d "$PROJECT_ROOT/backend" ]; then
    audit_npm "$PROJECT_ROOT/backend" "backend"
fi

# Audit Frontend
if [ -d "$PROJECT_ROOT/frontend" ]; then
    audit_npm "$PROJECT_ROOT/frontend" "frontend"
fi

# Generate combined report
echo -e "${YELLOW}Generating combined report...${NC}"

COMBINED_REPORT="$REPORT_DIR/COMBINED_REPORT.md"
cat > "$COMBINED_REPORT" <<EOF
# DhakaCart Dependency Security Audit

**Scan Date:** $(date)

## Summary

EOF

for file in "$REPORT_DIR"/*-audit.json; do
    if [ -f "$file" ]; then
        NAME=$(basename "$file" "-audit.json")
        CRITICAL=$(jq '.metadata.vulnerabilities.critical // 0' "$file")
        HIGH=$(jq '.metadata.vulnerabilities.high // 0' "$file")
        MODERATE=$(jq '.metadata.vulnerabilities.moderate // 0' "$file")
        LOW=$(jq '.metadata.vulnerabilities.low // 0' "$file")
        TOTAL=$(jq '.metadata.vulnerabilities.total // 0' "$file")
        
        cat >> "$COMBINED_REPORT" <<INNER
### $NAME

- **Total Vulnerabilities:** $TOTAL
- **Critical:** $CRITICAL
- **High:** $HIGH
- **Moderate:** $MODERATE
- **Low:** $LOW

INNER
    fi
done

cat >> "$COMBINED_REPORT" <<EOF

## Remediation

Run the following commands to fix vulnerabilities:

### Backend
\`\`\`bash
cd backend/
npm audit fix
# or for major version updates:
npm audit fix --force
\`\`\`

### Frontend
\`\`\`bash
cd frontend/
npm audit fix
# or for major version updates:
npm audit fix --force
\`\`\`

## Detailed Reports

- Backend: $REPORT_DIR/backend-audit.txt
- Frontend: $REPORT_DIR/frontend-audit.txt

EOF

echo -e "${GREEN}✓ Report generated${NC}"
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Audit Complete${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Reports saved to: $REPORT_DIR"
echo "Combined report: $COMBINED_REPORT"
echo ""

# Display combined report
cat "$COMBINED_REPORT"

echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Review detailed reports"
echo "2. Run 'npm audit fix' in each directory"
echo "3. Test application after updates"
echo "4. Commit updated package-lock.json"
echo ""

exit 0

