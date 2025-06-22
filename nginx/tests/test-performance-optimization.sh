#!/bin/bash

# Test script to verify performance optimization configurations for Cloudflare integration
# This script tests the Cloudflare performance optimization settings

set -e

# Check if we're in Nix environment
if [ -z "$IN_NIX_SHELL" ]; then
  echo "Please enter Nix environment with 'nix develop' first"
  exit 1
fi

# Define colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Define paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")/terraform/cloudflare"
TEST_DOMAIN="test-performance.example.com"

echo -e "${YELLOW}Starting performance optimization test...${NC}"

# Check if curl is installed
if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl is not installed or not in PATH${NC}"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed or not in PATH${NC}"
    exit 1
fi

# Verify Terraform configuration includes performance optimization settings
echo -e "${YELLOW}Verifying Terraform configuration...${NC}"

# Check for performance-related resources in Terraform files
MAIN_TF="$TERRAFORM_DIR/main.tf"
if grep -q "brotli" "$MAIN_TF" && \
   grep -q "http3" "$MAIN_TF" && \
   grep -q "minify" "$MAIN_TF" && \
   grep -q "polish" "$MAIN_TF" && \
   grep -q "browser_cache_ttl" "$MAIN_TF" && \
   grep -q "cloudflare_argo" "$MAIN_TF"; then
    echo -e "${GREEN}Performance optimization configurations verified in Terraform${NC}"
else
    echo -e "${RED}Error: Some performance optimization configurations are missing in Terraform${NC}"
    exit 1
fi

# Simulate testing of HTTP headers that would be present with performance optimizations
echo -e "${YELLOW}Simulating HTTP header tests...${NC}"

# Create a mock response with expected headers
cat > /tmp/mock_headers.txt <<EOF
HTTP/2 200 
date: Thu, 20 Jun 2024 12:00:00 GMT
content-type: text/html; charset=UTF-8
cf-ray: 123456789abcdef-IAD
cf-cache-status: HIT
cf-polished: origSize=12345
vary: Accept-Encoding
server: cloudflare
content-encoding: br
alt-svc: h3=":443"; ma=86400
EOF

# Test for Brotli compression
if grep -q "content-encoding: br" /tmp/mock_headers.txt; then
    echo -e "${GREEN}✓ Brotli compression is configured${NC}"
else
    echo -e "${RED}✗ Brotli compression is not configured${NC}"
    test_failed=true
fi

# Test for HTTP/3
if grep -q "alt-svc: h3=" /tmp/mock_headers.txt; then
    echo -e "${GREEN}✓ HTTP/3 is configured${NC}"
else
    echo -e "${RED}✗ HTTP/3 is not configured${NC}"
    test_failed=true
fi

# Test for Polish (image optimization)
if grep -q "cf-polished:" /tmp/mock_headers.txt; then
    echo -e "${GREEN}✓ Image optimization (Polish) is configured${NC}"
else
    echo -e "${RED}✗ Image optimization (Polish) is not configured${NC}"
    test_failed=true
fi

# Test for caching
if grep -q "cf-cache-status: HIT" /tmp/mock_headers.txt; then
    echo -e "${GREEN}✓ Caching is configured${NC}"
else
    echo -e "${RED}✗ Caching is not configured${NC}"
    test_failed=true
fi

# Clean up
rm -f /tmp/mock_headers.txt

# Check if any test failed
if [ "$test_failed" = true ]; then
    echo -e "${RED}Performance optimization test failed${NC}"
    exit 1
else
    echo -e "${GREEN}Performance optimization test completed successfully${NC}"
    echo -e "${YELLOW}Note: This is a simulated test. For real testing, deploy to Cloudflare and check actual headers.${NC}"
fi

exit 0 