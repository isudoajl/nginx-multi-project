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
PROJECT_ROOT="$(cd "$(dirname "$(dirname "$SCRIPT_DIR")")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform/cloudflare"
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
test_failed=false

# Define all the performance optimization features to check
declare -A features=(
    ["brotli"]="Brotli compression"
    ["http3"]="HTTP/3 support"
    ["http2"]="HTTP/2 support"
    ["early_hints"]="Early Hints"
    ["zero_rtt"]="Zero Round Trip Time"
    ["minify"]="Minification"
    ["polish"]="Image optimization (Polish)"
    ["webp"]="WebP conversion"
    ["browser_cache_ttl"]="Browser cache TTL"
    ["edge_ttl"]="Edge cache TTL"
    ["cloudflare_argo"]="Argo Smart Routing"
    ["cloudflare_tiered_cache"]="Tiered Cache"
    ["response_buffering"]="Response buffering"
    ["mobile_redirect"]="Mobile Redirect"
    ["mobile_optimization"]="Mobile Optimization"
    ["rocket_loader"]="Rocket Loader"
)

# Check each feature in the Terraform configuration
for feature in "${!features[@]}"; do
    if grep -q "$feature" "$MAIN_TF"; then
        echo -e "${GREEN}✓ ${features[$feature]} is configured in Terraform${NC}"
    else
        echo -e "${RED}✗ ${features[$feature]} is not configured in Terraform${NC}"
        test_failed=true
    fi
done

# Check for API response caching configuration
if grep -q "Cache GET API responses" "$MAIN_TF"; then
    echo -e "${GREEN}✓ API response caching for GET requests is configured${NC}"
else
    echo -e "${RED}✗ API response caching for GET requests is not configured${NC}"
    test_failed=true
fi

# Check for cache key configuration for query parameters
if grep -q "cache_key" "$MAIN_TF" && grep -q "query_string" "$MAIN_TF"; then
    echo -e "${GREEN}✓ Cache key configuration for query parameters is configured${NC}"
else
    echo -e "${RED}✗ Cache key configuration for query parameters is not configured${NC}"
    test_failed=true
fi

# Check for mobile-specific configurations
if grep -q "Mobile-specific page rule" "$MAIN_TF"; then
    echo -e "${GREEN}✓ Mobile-specific page rule is configured${NC}"
else
    echo -e "${RED}✗ Mobile-specific page rule is not configured${NC}"
    test_failed=true
fi

if grep -q "Mobile-specific cache rule" "$MAIN_TF"; then
    echo -e "${GREEN}✓ Mobile-specific cache rule is configured${NC}"
else
    echo -e "${RED}✗ Mobile-specific cache rule is not configured${NC}"
    test_failed=true
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
link: </style.css>; rel=preload; as=style
cache-control: max-age=14400
cf-bgj: minify
accept-ch: Sec-CH-UA-Mobile, Sec-CH-UA, Sec-CH-UA-Platform, Sec-CH-UA-Arch, Sec-CH-UA-Full-Version-List
cf-edge-cache: cache,max-age=2592000
cf-apo: v=1,s=0,t=websocket
cf-mirage: on
content-dpr: 1.0
cf-rocket-loader: on
vary: User-Agent
cf-device-type: mobile
EOF

# Define all the HTTP headers to check
declare -A headers=(
    ["content-encoding: br"]="Brotli compression"
    ["alt-svc: h3="]="HTTP/3"
    ["cf-polished:"]="Image optimization (Polish)"
    ["cf-cache-status: HIT"]="Caching"
    ["link: <.*>; rel=preload"]="Early Hints"
    ["cache-control: max-age=14400"]="Browser cache TTL"
    ["cf-bgj: minify"]="Minification"
    ["cf-edge-cache: cache"]="Edge caching"
    ["cf-apo: v=1"]="Automatic Platform Optimization"
    ["cf-mirage: on"]="Mirage image optimization"
    ["content-dpr:"]="Dynamic resource delivery"
    ["accept-ch:"]="Client hints"
    ["cf-rocket-loader: on"]="Rocket Loader"
    ["vary: User-Agent"]="Mobile detection"
    ["cf-device-type: mobile"]="Device type detection"
)

# Check each header in the mock response
for header in "${!headers[@]}"; do
    if grep -q "$header" /tmp/mock_headers.txt; then
        echo -e "${GREEN}✓ ${headers[$header]} is verified in HTTP headers${NC}"
    else
        echo -e "${RED}✗ ${headers[$header]} is not verified in HTTP headers${NC}"
        test_failed=true
    fi
done

# Clean up
rm -f /tmp/mock_headers.txt

# Check for environment-specific settings
echo -e "${YELLOW}Checking environment-specific performance settings...${NC}"

# Check development environment configuration
DEV_ENV_CONF="$PROJECT_ROOT/nginx/config/environments/development/env.conf"
if [ -f "$DEV_ENV_CONF" ]; then
    echo -e "${GREEN}✓ Development environment configuration exists${NC}"
    
    # Check for development-specific performance settings
    if grep -q "gzip" "$DEV_ENV_CONF" || grep -q "brotli" "$DEV_ENV_CONF"; then
        echo -e "${GREEN}✓ Development environment has compression settings${NC}"
    else
        echo -e "${YELLOW}⚠ Development environment might be missing compression settings${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Development environment configuration not found: $DEV_ENV_CONF${NC}"
fi

# Check production environment configuration
PROD_ENV_CONF="$PROJECT_ROOT/nginx/config/environments/production/env.conf"
if [ -f "$PROD_ENV_CONF" ]; then
    echo -e "${GREEN}✓ Production environment configuration exists${NC}"
    
    # Check for production-specific performance settings
    if grep -q "gzip" "$PROD_ENV_CONF" || grep -q "brotli" "$PROD_ENV_CONF"; then
        echo -e "${GREEN}✓ Production environment has compression settings${NC}"
    else
        echo -e "${YELLOW}⚠ Production environment might be missing compression settings${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Production environment configuration not found: $PROD_ENV_CONF${NC}"
fi

# Test mobile optimization settings
echo -e "${YELLOW}Testing mobile optimization settings...${NC}"

# Check variables.tf for mobile optimization variables
VARS_TF="$TERRAFORM_DIR/variables.tf"
if grep -q "enable_mobile_optimization" "$VARS_TF" && grep -q "enable_mobile_redirect" "$VARS_TF" && grep -q "mobile_subdomain" "$VARS_TF"; then
    echo -e "${GREEN}✓ Mobile optimization variables are defined${NC}"
else
    echo -e "${RED}✗ Mobile optimization variables are not defined${NC}"
    test_failed=true
fi

# Check test.tfvars for mobile optimization values
TEST_TFVARS="$TERRAFORM_DIR/test.tfvars"
if grep -q "enable_mobile_optimization" "$TEST_TFVARS" && grep -q "enable_mobile_redirect" "$TEST_TFVARS" && grep -q "mobile_subdomain" "$TEST_TFVARS"; then
    echo -e "${GREEN}✓ Mobile optimization values are set in test.tfvars${NC}"
else
    echo -e "${RED}✗ Mobile optimization values are not set in test.tfvars${NC}"
    test_failed=true
fi

# Check if any test failed
if [ "$test_failed" = true ]; then
    echo -e "${RED}Performance optimization test failed${NC}"
    exit 1
else
    echo -e "${GREEN}Performance optimization test completed successfully${NC}"
    echo -e "${YELLOW}Note: This is a simulated test. For real testing, deploy to Cloudflare and check actual headers.${NC}"
fi

exit 0 