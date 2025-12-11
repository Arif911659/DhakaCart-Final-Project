#!/bin/bash

# Frontend Production Build Script
# Purpose: Build and push frontend Docker image with production stage

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
IMAGE_NAME="arifhossaincse22/dhakacart-frontend"
VERSION="${1:-v1.0.3}"
TARGET_STAGE="production"

echo -e "${GREEN}🏗️  Building Frontend Production Image${NC}"
echo "Image: ${IMAGE_NAME}:${VERSION}"
echo "Target Stage: ${TARGET_STAGE}"
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Error: Docker not found!${NC}"
    exit 1
fi

# Build image with production target
echo -e "${GREEN}📦 Building Docker image...${NC}"
docker build --target $TARGET_STAGE -t ${IMAGE_NAME}:${VERSION} .

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Build failed!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build successful!${NC}"
echo ""

# Verify image
echo -e "${GREEN}🔍 Verifying image...${NC}"
echo "Testing container startup..."

# Test run
CONTAINER_ID=$(docker run -d -p 8080:80 --name test-frontend-$$ ${IMAGE_NAME}:${VERSION} 2>/dev/null || echo "")

if [ -z "$CONTAINER_ID" ]; then
    echo -e "${RED}❌ Error: Container failed to start!${NC}"
    exit 1
fi

sleep 2

# Test HTTP response
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 2>/dev/null || echo "000")

# Cleanup
docker stop test-frontend-$$ > /dev/null 2>&1
docker rm test-frontend-$$ > /dev/null 2>&1

if [ "$HTTP_CODE" != "200" ]; then
    echo -e "${YELLOW}⚠️  Warning: HTTP test returned code $HTTP_CODE${NC}"
    echo "Image built but verification failed. Continue anyway? (y/n)"
    read -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}✅ Image verification successful!${NC}"
fi

echo ""

# Push to registry
echo -e "${GREEN}📤 Pushing image to registry...${NC}"
echo "This may take a few minutes..."
docker push ${IMAGE_NAME}:${VERSION}

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Push failed!${NC}"
    echo "You may need to login: docker login"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Image pushed successfully!${NC}"
echo ""
echo "Next steps:"
echo "  1. Update deployment:"
echo "     kubectl set image deployment/dhakacart-frontend frontend=${IMAGE_NAME}:${VERSION} -n dhakacart"
echo ""
echo "  2. Wait for rollout:"
echo "     kubectl rollout status deployment/dhakacart-frontend -n dhakacart"
echo ""
echo "  3. Verify:"
echo "     kubectl exec -n dhakacart <pod-name> -- curl -I http://localhost:80"
echo ""

